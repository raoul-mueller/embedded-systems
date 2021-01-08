const mqtt = require('mqtt');
const config = require('../config');

module.exports = async () => {
    const client = mqtt.connect(config.mqttUrl, {
        //clientId: "gruppe7Backend",
        username: config.mqttUser,
        password: config.mqttPassword,
        //clean: false
    });

    const channels = [
        config.mqttEventChannel,
    ]

    client.on('connect', () => {
        channels.forEach((channel) => {
            client.subscribe(config.mqttChannelBase + channel, (err) => {
                if (!err) {
                    console.log(`Subscribed to ${channel}`);
                }
            });
        });
    });

    return client;
}
