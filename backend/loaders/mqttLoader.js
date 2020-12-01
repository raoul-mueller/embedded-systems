const mqtt = require('mqtt');
const config = require('../config');

module.exports = async () => {
    var client  = mqtt.connect(config.mqttUrl, {
        //clientId: "gruppe7Backend",
        username: config.mqttUser,
        password: config.mqttPassword,
        //clean: false
      });
      
      client.on('connect', function () {
        console.log('Connected');
        client.subscribe('ES/WS20/gruppe7/events', function (err) {
          if (!err) {
            console.log('Subscribed to ES/WS20/gruppe7/events');
          }
        })
      });
       
      client.on('message', function (topic, message) {
        // handle device updates
      
        console.log(topic);
        console.log(message.toString());
      });

      return client;
}
