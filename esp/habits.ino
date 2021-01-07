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
//#define DEBUG
//#define DEBUG_WIFI
//#define DEBUG_SENSOR_VALUES




#include <WiFiManager.h> /// https://github.com/tzapu/WiFiManager
WiFiManager wm;


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
DHT dht(27, DHT11);
//DHT dht(27, DHT22);


#include <TFT_eSPI.h>  /// https://github.com/Bodmer/TFT_eSPI
#include <SPI.h>



const int updateDelay = 10; /// uploading values every 'X' seconds to Database
const int readingsPerSecond = 4;

const int trebbleStep = 6;

const int trebbleStanding = 10; /// in degree

const int heatindexOffset = 5; ///in °C
const double roomHeatindex = 22.0; //default room temperature

//TODO: get Data from database (hours standed, steps made, hours outside for actual day)
//long stepsDone = 0;
//int hoursStanded = 0;
//int hoursOutside = 0;


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

    #ifdef DEBUG_WIFI
    Serial.println("Initialize WiFi-Manager");
    Serial.println();
    #else
    wm.setDebugOutput(false);
    #endif
    WiFi.mode(WIFI_STA);

    //reset settings - wipe credentials for testing
    //wm.resetSettings();
    
    wm.setConfigPortalTimeout(30); ///turning down configuration site every X seconds to check if last known wifi is available again

    onDisconnected();

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
    
  if(WiFi.status() == WL_CONNECTED){
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
    Serial.println("Disconnected");
    Serial.println();
    Serial.println();
    #endif
  
    bool res = false;
    while(!res){
      res = wm.autoConnect(); 

      #ifdef DEGBUG_WIFI
      Serial.println();
      if(!res) {
        Serial.println("Failed to connect");
      } else Serial.println("connected...yeey :)");
      Serial.println();
      #endif
    }
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
  
  //TODO: eventuell, wenn standing = false, steps auf 0 setzen, um fehler zu minimieren?
  
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


  if(WiFi.status() == WL_CONNECTED){
    #ifdef DEBUG_WIFI
    Serial.println("Uploading data to database...");
    #endif
    //TODO: upload values to database and display on tft
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
