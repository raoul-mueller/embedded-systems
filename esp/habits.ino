/**
 * Eingebttete Systeme 2020/2021 - Habits (Gruppe 8)
 * 
 * 
 * This file is ment for the esp32 to measure and calculate if a user is standing, outside and how many steps 
 * the user made since the last measurement. The data is then send to an MQTT-Server and stored in a database.
 * 
 * NOTE: No absolute data like how long the user was standing the actual day, how long he was outside or how
 *       many steps he made is saved on the device (only temporary data of last X seconds). All this information 
 *       is stored on a database and requested when needed (for example for displaying on tft-display)
 * 
 * 
 * The user can see the information using our app (on mobile phone) or looking at the build in tft display of
 * the esp32 ttgo.
 * 
 * The user needs to connect the device to an woring WiFi-Network with internet connection. To provide the user
 * an easy way of doing that the device automatically checks, if it is connected to a WiFi. If so it works properly.
 * If its not connected to a WiFi then the device is going to configuration mode (see Function onDisconnected() below).
 * In this mode the device checks every X seconds if the last known WiFi is available and connects to it again. In this
 * mode the user can also directily connect his Smartphone, Laptop, or anything else to the device and set up another 
 * (new on first start) WiFi-Connection. The WiFi information is stored on the device, so it will try to connect
 * when powered.
 * 
 * 
 * 
 * @version 2 created by Daniel Grigorasch on 29.12.2020
 * @authors Raoul Müller, Gordon Kirsch, Nils Betten, Daniel Grigorasch
 * 
 */



///Debug settings
#define DEBUG
#define DEBUG_WIFI
//#define DEBUG_SENSOR_VALUES




#include <WiFiManager.h> ///https://github.com/tzapu/WiFiManager
WiFiManager wm;


#include <PubSubClient.h> ///https://github.com/knolleary/pubsubclient
WiFiClient espClient;
PubSubClient client(espClient);
const char* mqttServer = "hrw-fablab.de";
const int mqttPort = 1883;
const char* mqttUsername = "gruppe7";
const char* mqttPassword = "eitaVkieXTqe8UNe";


#include <ArduinoJson.h> ///https://arduinojson.org/?utm_source=meta&utm_medium=library.properties
StaticJsonDocument<1024> jsonDoc;


/**
 * MPU6050 Triple Axis Gyroscope & Accelerometer. Pitch & Roll Accelerometer Example.
 * Read more: http://www.jarzebski.pl/arduino/czujniki-i-sensory/3-osiowy-zyroskop-i-akcelerometr-mpu6050.html
 * GIT: https://github.com/jarzebski/Arduino-MPU6050
 * Web: http://www.jarzebski.pl
 * (c) 2014 by Korneliusz Jarzebski
 */
#include <Wire.h>
#include <MPU6050.h>
MPU6050 mpu;


#include <DHT.h> ///https://github.com/adafruit/DHT-sensor-library
//DHT dht(27, DHT11);
DHT dht(27, DHT22);


#define FS_NO_GLOBALS
#include <FS.h>
#include "SPIFFS.h"
#include <JPEGDecoder.h>
#include <TFT_eSPI.h> /// https://github.com/Bodmer/TFT_eSPI

TFT_eSPI tft = TFT_eSPI();


#include <Tone32.h> ///https://github.com/lbernstone/Tone32
const int buzzer_pin = 32;
const int buzzer_channel = 0;





const int updateDelay = 20; /// uploading values every 'X' seconds to Database
const int readingsPerSecond = 4;

const int trebbleStep = 6;

const int trebbleStanding = 10; /// in degree

const int heatindexOffset = 5; ///in °C
const double roomHeatindex = 22.0; //default room temperature

int lastScore = -1;
int lastTotalSteps = -1;
double lastTotalStanding = -1;
double lastTotalOutside = -1;


/**
 * Setup:
 * 
 * 1. Starting serial comunication
 * 2. Wait for MPU to start
 * 3. Setup WiFi-Manager
 * 4. Wait for WiFi to connect to last WiFi known, or to new one if configured over esp-webserver
 */
void setup() {
    Serial.begin(115200);
    startupSound();
    delay(3000);


    #ifdef DEBUG
    Serial.println("++++++++++ setup() ++++++++++");
    Serial.println();
    Serial.println("Initialize MPU6050...");
    #endif
    while(!mpu.begin(MPU6050_SCALE_2000DPS, MPU6050_RANGE_2G)){
      #ifdef DEBUG_SENSOR_VALUES
      Serial.println("Could not find a valid MPU6050 sensor, check wiring!");
      #endif
      delay(500);
    }


    #ifdef DEBUG
    Serial.println("Initialize TFT-Display and drawing images...");
    #endif
    tft.begin();
    tft.setRotation(0);
    tft.fillScreen(TFT_BLACK);

    if (!SPIFFS.begin()) {
      #ifdef DEBUG
      Serial.println("SPIFFS initialisation failed!");
      #endif
      while (1) yield(); // Stay here twiddling thumbs waiting  
    }
    Serial.println("\r\nInitialisation done.");
    #ifdef DEBUG
    listFiles(); // Lists the files so you can see what is in the SPIFFS
    #endif

    
    drawJpeg("/no_wifi.jpeg", 0 , 0);
    drawJpeg("/battery.jpeg", 95, 0); ///prepared for later use

    tft.drawLine(0, 45, 135, 45, TFT_WHITE);
  
    drawJpeg("/score.jpeg", 0, 65);
    drawJpeg("/standing.jpeg", 0, 110);
    drawJpeg("/outside.jpeg", 0, 155);
    drawJpeg("/steps.jpeg", 0, 200);


    dht.begin();
    

    #ifdef DEBUG_WIFI
    Serial.println("Initialize WiFi-Manager...");
    Serial.println();
    #else
    wm.setDebugOutput(false);
    #endif
    WiFi.mode(WIFI_STA);

    //reset settings - wipe credentials for testing
    //wm.resetSettings();
    
    wm.setConfigPortalTimeout(30); ///turning down configuration site every X seconds to check if last known wifi is available again


    #ifdef DEBUG_WIFI
    Serial.println("Initialize MQTT-connection:");
    Serial.println();
    #endif
    client.setServer(mqttServer, mqttPort);
    client.setCallback(displayTFT);
    

    onDisconnected();

    uploadValues(0, false, false); //Uploading nothing to get data on tft display

    #ifdef DEBUG
    Serial.println();
    Serial.println();
    Serial.println("++++++++++ setup() done ++++++++++");
    Serial.println("_________________________________________________________________________________________");
    Serial.println();
    Serial.println();
    #endif
}




/**
 * Loop checking every time for Wifi to be connected to esp.
 * If so then running normal code.
 * If not then opening configuration webserver and trying to reconnect to old network again
 */
void loop() {
  #ifdef DEBUG
  Serial.println("++++++++++ loop() ++++++++++");
  #endif
    
  if(WiFi.status() == WL_CONNECTED && client.connected()){
    onConnected();
  }else onDisconnected();
  delay(1000);

  #ifdef DEBUG
  Serial.println("++++++++++ loop() end ++++++++++");
  Serial.println("_________________________________________________________________________________________");
  Serial.println();
  Serial.println();
  #endif
}

/**
 * Function keeps running in while-loop until connection with a wifi is established.
 * This can happen if a new wifi was configured successfully configured or the known one was found again.
 * 
 * Note: Last known wifi is checked every X seconds (see wm.setConfigPortalTimeout(X);).
 * During this time configuration website is unavailable.
 * Function stays for X seconds @wm.autoConnect();
 */
void onDisconnected(){
    #ifdef DEBUG_WIFI
    Serial.println("---- onDisconnected() ----");
    Serial.println();
    #endif
    
    drawJpeg("/no_wifi.jpeg", 0 , 0);
    connectionLostSound();
  
    bool res = false;
    while(!res){
      res = wm.autoConnect(); 
      bool mqqtSuccess = onReconnectMQTT();
      if(!mqqtSuccess){
        res = false;
      }

      #ifdef DEBUG_WIFI
      Serial.println();
      if(!res) {
        Serial.println("Failed to connect. Trying again ...");
      } else Serial.println("connected ...");
      Serial.println();
      #endif
    }
    
    drawJpeg("/wifi.jpeg", 0 , 0);
    connectionEstablishedSound();


    #ifdef DEBUG_WIFI
    Serial.println();
    Serial.println();
    #endif
}


/**
 * Trying to connect to to mqqt-Server while internet connection is available. If internet connection fails function quits.
 * If connection is successfull topic ""ES/WS20/gruppe7/<<boardID>>" is subscribed 
 * (daily values are stored here. After esp sends current data daily data is send back to this topic)
 * 
 * @return returns true if connection is successfull, otherwise returning false
 */
bool onReconnectMQTT(){
  #ifdef DEBUG_WIFI
  Serial.println("---- onReconnectMQTT() ----");
  Serial.println();
  #endif
  
  while(!client.connected()){
    #ifdef DEBUG_WIFI
    Serial.println("Trying to connect to mqtt server...");
    #endif
    
    if(WiFi.status() != WL_CONNECTED){
      #ifdef DEBUG_WIFI
      Serial.println("WiFi-connection failed. Quitting method and trying again ...");
      #endif
      
      return false;
    }else if(client.connect(wm.getDefaultAPName().c_str(), mqttUsername, mqttPassword)){
      /// subscribing to channel named after the borardID (so each esp has its own channel)
      //@gordon funktioniert (stand jetzt) nicht
      String topic = "ES/WS20/gruppe7/" + wm.getDefaultAPName();

      
      //@gordon funktioniert
      //String topic = "ES/WS20/gruppe7/events";
      
      bool subscribed = client.subscribe(topic.c_str());
      #ifdef DEBUG_WIFI
      Serial.print("Subscribtion successfull: ");
      Serial.println(subscribed);
      #endif

      #ifdef DEBUG_WIFI
      Serial.print("MQTT-connection successfull. Subscirbing channel \"");
      Serial.print(topic);
      Serial.println("\"");
      #endif
    }
    delay(1000);
  }
  return true;
}


/**
 * Function is measuring and evaluation sensor data.
 * 
 * 1. Calculating number of measurements and defining temporary variables
 * 2. Running for loop:
 *      check if a step was made. If so add one step to steps
 *      check if person is standing. If so add one to standingValue
 *      calculate heatindex with measured temperature and humidity and add it to variable heatindex
 *      delay depends on the time the for-loop should run and on the number of measurements to be taken
 * 3. Calculate mean of the standing value and convert it to boolean (0 = false, 1 = true)
 * 4. Calculate mean of heatindex and convert it to boolean (true if difference between heatindex and roomHeatindex is bigger than heatindexOffset, otherwise false)
 * 5. Upload data to database if WiFi is still available and update tft display
 * 
 * NOTE: for the stepped()-function working properly you have to chose the param readingsPerSecond carefully. 
 *       Too few readings will result in steps beeing undetected. Too many readings will result in too many steps detected during one step.
 * NOTE: esp wont upload measured data if no wifi connection is available after measuring. The data will be lost. Use propper updateDelay
 */
void onConnected(){
  int numberMeasurements = updateDelay * readingsPerSecond;
  
  #ifdef DEBUG_WIFI
  Serial.println("WiFi Connected. Reading sensor values...");
  #endif
  
  #ifdef DEBUG
  Serial.println("---- onConnected() ----");
  Serial.print("There will be ");
  Serial.print(numberMeasurements);
  Serial.print(" measurements with ");
  Serial.print(readingsPerSecond);
  Serial.print(" measurements per second. This will take ");
  Serial.print(updateDelay);
  Serial.println(" seconds");
  #endif

  float tempLastNorm;
  int steps = -1; ///first reading always a step
  int standingValue = 0; /// 0 for false 1 for true
  float heatindex = 0;
  
  for(int i=0; i<numberMeasurements; i++){
     client.loop();
     
    #ifdef DEBUG_SENSOR_VALUES
    Serial.println("______________________________");
    Serial.println();
    Serial.print("for-loop ");
    Serial.print(i);
    Serial.println(":");
    #endif
    
    Vector normAccel = mpu.readNormalizeAccel();

    if(stepped(normAccel, tempLastNorm)){
      steps++;
    }
    
    bool tempIsStanding = isStanding(normAccel);
    if(tempIsStanding){
      standingValue++;
    }

    float temperature = dht.readTemperature();
    float humidity = dht.readHumidity();
    float tempHeatindex = dht.computeHeatIndex(temperature, humidity, false); ///false = in degree celsius
    heatindex += tempHeatindex;


    #ifdef DEBUG_SENSOR_VALUES
    Serial.println("---- is outside ----");
    Serial.print("Temperature: ");
    Serial.print(temperature);
    Serial.print(", humidity: ");
    Serial.print(humidity);
    Serial.print(", heatindex: ");
    Serial.print(tempHeatindex);
    Serial.println("°C");

    bool tempOutside = int(abs(heatindex - roomHeatindex)) > heatindexOffset;
    if(tempOutside){
      Serial.println("Outside = true");
    }else Serial.println("Ouside = false");
    #endif 


    delay(updateDelay*1000/numberMeasurements); ///Should be 50 milliseconds for stepped function
  }

  bool standing = int(round((double)standingValue / (double)numberMeasurements)) == 1;
  
  ///if standing is false (so the System assumes person wasnt standing in the last x seconds) steps couldnt be made, so steps is set to 0
  if(!standing || steps < 0){
    steps = 0;
  }
  
  bool outside = int(abs((heatindex / (double)numberMeasurements) - roomHeatindex)) > heatindexOffset;

  #ifdef DEBUG_SENSOR_VALUES
  Serial.println("______________________________");
  Serial.println();
  Serial.println();
  #endif
  
  #ifdef DEBUG
  Serial.print("Steps since last calculation: ");
  Serial.print(steps);
  Serial.print(",\tStanding: ");
  Serial.print(standing);
  Serial.print(",\tOutside:");
  Serial.println(outside);
  #endif

  
  if(WiFi.status() == WL_CONNECTED && client.connected()){
    uploadValues(steps, standing, outside);
  }else {
    #ifdef DEBUG_WIFI
    Serial.println("Connection could not been established. Upload to database failed!");
    #endif
  }

  #ifdef DEBUG
  Serial.println();
  Serial.println();
  #endif
}

/**
 * Uploading values of last X seconds of measurement to Server (using mqtt).
 * 
 * First creating JSON Document. Example:
 * { 
 *    “boardID”: “xyz”, 
 *    “standing”: true, 
 *    “stepsSinceLastUpdate”: 5, 
 *    “outside”: true 
 * }
 * 
 * Then publishing it to MQTT Server (Topic is "ES/WS20/gruppe7/events")
 */
void uploadValues(int steps, bool standing, bool outside){
  #ifdef DEBUG_WIFI
  Serial.println("Uploading data to database...");
  #endif

  jsonDoc["boardID"] = wm.getDefaultAPName();
  jsonDoc["standing"] = standing;
  jsonDoc["stepsSinceLastUpdate"] = steps;
  jsonDoc["outside"] = outside;

  String output; 
  serializeJsonPretty(jsonDoc, output);

  #ifdef DEBUG_WIFI
  Serial.println("JSON File:");
  Serial.println("-------------------------------------------------------");
  Serial.println(output);
  Serial.println("-------------------------------------------------------");
  #endif

  client.publish("ES/WS20/gruppe7/events", output.c_str());
  delay(100);

  jsonDoc.clear();
}


/**
 * This function is called if a message is passed to the topic subscribed (each board has its own channel named after boardID)
 * First casting message (byte*) into an String to deserialize the Json-File.
 * Then reading all relevant data (steps, standing, outside). NOTE: This data is from whole day
 * If data changed after last reading, it is stored and displayed onto tft-screen
 * 
 * @param topic topic of subscribtion (mqtt)
 * @param message message revcieved by subscribtion (mqtt)
 * @param length length of message (not needed in this case: casting message to String)
 */
void displayTFT(char* topic, byte* message, unsigned int length) {
  #ifdef DEBUG_WIFI
  Serial.print("Message arrived on topic: ");
  Serial.println(topic);
  #endif
  
  String messageTemp;
  
  for (int i = 0; i < length; i++) {
    messageTemp += (char)message[i];
  }
  
  #ifdef DEBUG_WIFI
  Serial.println("Message: ");
  Serial.println(messageTemp);
  #endif

  deserializeJson(jsonDoc, messageTemp);
  int score = jsonDoc["score"]["current"];
  int steps = jsonDoc["steps"]["current"];
  double standing = jsonDoc["standing"]["current"];
  double outside = jsonDoc["outside"]["current"];


  #ifdef DEBUG
  Serial.println("Displaying TFT...");
  #endif

  if(score != lastScore){
    tft.setCursor(45, 75, 4);
    tft.print(String(score));
    lastScore = score;
  }
  if(standing != lastTotalStanding){
    int hoursStanding = round(standing);
    int minStanding = hoursStanding % 60;
    hoursStanding /= 60;
    
    String output = String(hoursStanding) + ":";
    if(minStanding < 10){
      output += "0";
    }
    output += String(minStanding);
    if(minStanding >= 10 && minStanding % 10 == 0){
      output += "0";
    }
    output += " h";
    
    tft.setCursor(45, 120, 4);
    tft.print(output);
    lastTotalStanding = standing;
  }
  
  if(outside != lastTotalOutside){
    int hoursOutside = round(outside);
    int minOutside = hoursOutside % 60;
    hoursOutside /= 60;

    String output = String(hoursOutside) + ":";
    if(minOutside < 10){
      output += "0";
    }
    output += String(minOutside);
    if(minOutside >= 10 && minOutside % 10 == 0){
      output += "0";
    }
    output += " h";
    
    tft.setCursor(45, 165, 4);
    tft.print(output);
    lastTotalOutside = outside;
  }
  if(steps != lastTotalSteps){
    tft.setCursor(45, 210, 4);
    tft.print(String(steps));
    lastTotalSteps = steps;
  }

  jsonDoc.clear();
}





///Sensor measurement functions


/**
 * Function checks if a step was made during last reading.
 * The calculation is very simple and only interprets changes in acceleration as a step
 * 
 * 1. normalizing x if bigger than 6 and y and z if bigger than 5 (This numbers where choosen by testing).
 *    By normalizing we just substract 39.3 (we got this value by testing) and invert number (makeing it positive)
 * 2. calculating norm of vector (x,y,z)
 * 3. checking if difference between calculated norm and last norm is bigger than trebbleStep
 * 4. save current norm in last norm
 * 
 * @param normAccel = Vector containging x,y,z acceleration
 * @param lastNorm = Reference to last norm calulated (new norm is stored in this value)
 * @return ture if a step was detected, false if not
 */
bool stepped(Vector normAccel, float &lastNorm){
    /// normalizing x, y, or z if greater than 5/6;
    float x = normAccel.XAxis;
    if(x > 6){    
      ///39.3 got by testing
      x = -(x - 39.3);
    }
    
    float y = normAccel.YAxis;
    if(y > 5){    
      ///39.3 got by testing
      y = -(y - 39.3);
    }
    
    float z = normAccel.ZAxis;
    if(z > 5){    
      ///39.3 got by testing
      z = -(z - 39.3);
    }
    
    float norm = sqrt(x*x + y*y + z*z);

    #ifdef DEBUG_SENSOR_VALUES
    Serial.println("---- stepped() ----");
    Serial.print("x = ");
    Serial.print(x);
    Serial.print(", y = ");
    Serial.print(y);
    Serial.print(", z = ");
    Serial.print(z);
    Serial.print(" -> norm:");
    Serial.print(norm);
    Serial.print(", last norm: ");
    Serial.println(lastNorm);
    #endif
    
    if(abs(norm - lastNorm) > trebbleStep){
      #ifdef DEBUG_SENSOR_VALUES
      Serial.println("Standing: true");
      Serial.println();
      #endif
      
      lastNorm = norm;
      return true;
    }

    #ifdef DEBUG_SENSOR_VALUES
    Serial.println("Standing: false");
    Serial.println();
    #endif
    
    lastNorm = norm;
    return false;
}

/**
 * Function checks if person is standing by calculating the degree of pitch and roll using the momentary acceleration.
 * 
 * 1. If x is smaller or even 6 (value found while testing) the sensor is over 90 degrees turned on one side (not the x axis). 
 *    You can imagine it like a sphere where we know we are at the bottom half of it if x >= 6. We dont know the exact angle of 
 *    this position, but we know that a person cannot be standing, so we return false. Otherwise we continue reading the angles.
 * 2. normalizing y and z if bigger than 5 (This numbers where choosen by testing).
 *    By normalizing we just substract 39.3 (we got this value by testing) and invert number (makeing it positive)
 * 3. Calculating pitch and roll with arctan(x / y or z) multiplying with 180 and dividing by pi (for radian measure). 
 *    Then moving angle by 90 degree. So we have pitch and roll = 0 when sensor is straight
 * 4. Checking if roll and/or pitch is greater than trebbleStanding. Therefore roll is multiplied by 0.2, otherwise it will be to sensitive compared to pitch.
 * 
 * @param normAccel Vecor (x, y, z)
 * @return true if person is standing (sensor is straight), otherwise false
 * 
 * NOTE: Calculations depend on how the sensor will be placed during "standing position"
 */
bool isStanding(Vector normAccel){
    /// Calculate Pitch & Roll
    float x = normAccel.XAxis;
    if(x <= 6){
      float y = normAccel.YAxis;
      if(y > 5){    
        ///39.3 got by testing
        y = -(y - 39.3);
      }
    
      float z = normAccel.ZAxis;
      if(z > 5){
        ///39.3 got by testing
        z = -(z - 39.3);
      }
    
    
    
      int pitch = 90-(atan(normAccel.XAxis / y)*180.0)/M_PI;
      int roll = 90-(atan(normAccel.XAxis/ z)*180.0)/M_PI;
  
  
      #ifdef DEBUG_SENSOR_VALUES
      Serial.println("---- isStanding() ----");
      Serial.print("x = ");
      Serial.print(x);
      Serial.print(", y = ");
      Serial.print(y);
      Serial.print(", z = ");
      Serial.print(z);
      Serial.print("Pitch = ");
      Serial.print(pitch);
      Serial.print("°, Roll = ");
      Serial.println(roll);
      #endif
  
      if(pitch < trebbleStanding && 0.2*roll < trebbleStanding){
        #ifdef DEBUG_SENSOR_VALUES
        Serial.println("Standing = true");
        Serial.println();
        #endif
        
        return true;
      }
    }

    #ifdef DEBUG_SENSOR_VALUES
    Serial.println("Standing = false");
    Serial.println();
    #endif
 
    return false;
}







///Sounds


/**
 * Startupsound
 * 
 * 300 ms g4
 * 75 ms a4
 * 75 ms c5
 * 75 ms e5
 */
void startupSound(){
  tone(buzzer_pin, NOTE_G4, 300, buzzer_channel);
  noTone(buzzer_pin, buzzer_channel);
  tone(buzzer_pin, NOTE_A4, 75, buzzer_channel);
  noTone(buzzer_pin, buzzer_channel);
  tone(buzzer_pin, NOTE_C5, 75, buzzer_channel);
  noTone(buzzer_pin, buzzer_channel);
  tone(buzzer_pin, NOTE_E5, 75, buzzer_channel);
  noTone(buzzer_pin, buzzer_channel);
}


/**
 * Sound which is played when, connection to WiFi or to MQTT-Server is lost
 * 
 * 140 ms g4
 * delay 10 ms
 * 140 ms d4
 * delay 10 ms
 */
void connectionLostSound(){
  tone(buzzer_pin, NOTE_G4, 140, buzzer_channel);
  noTone(buzzer_pin, buzzer_channel);
  delay(10);
  tone(buzzer_pin, NOTE_D4, 140, buzzer_channel);
  noTone(buzzer_pin, buzzer_channel);
  delay(10);
}

/**
 * Sound which is played when, connection to WiFi and to MQTT-Server is established
 * 
 * 140 ms g4
 * delay 10 ms
 * 140 ms d5
 * delay 10 ms
 */
void connectionEstablishedSound(){
  tone(buzzer_pin, NOTE_G4, 140, buzzer_channel);
  noTone(buzzer_pin, buzzer_channel);
  delay(10);
  tone(buzzer_pin, NOTE_D5, 140, buzzer_channel);
  noTone(buzzer_pin, buzzer_channel);
  delay(10);
}
