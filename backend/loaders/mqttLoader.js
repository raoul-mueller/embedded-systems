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
        client.subscribe('ES/WS20/gruppe7/events', function (err) {
          if (!err) {
            console.log('Subscribed to ES/WS20/gruppe7/events');
          }
        })
      });

      return client;
}
