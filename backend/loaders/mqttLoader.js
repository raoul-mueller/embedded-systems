const mqtt = require('mqtt');
const config = require('../config');

module.exports = async () => {
    const client = mqtt.connect(config.mqttUrl, {
        //clientId: "gruppe7Backend",
        username: config.mqttUser,
        password: config.mqttPassword,
        //clean: false
      });
      
      client.on('connect', () => {
        client.subscribe(config.mqttChannel, (err) => {
          if (!err) {
            console.log(`Subscribed to ${config.mqttChannel}`);
          }
        });
      });

      return client;
}
