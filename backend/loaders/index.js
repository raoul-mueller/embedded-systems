const mqttLoader = require('./mqttLoader');
const wsLoader = require('./wsLoader');
const mongooseLoader = require('./mongooseLoader');
const EventHandleService = require('../services/eventHandleService');
const expressLoader = require('./expressLoader');

module.exports = async () => {
    let mqttClient = await mqttLoader();
    console.log('MQTT Client loaded!');

    let wss = await wsLoader();
    console.log('WebSocket Server loaded!')

    let mongooseDb = await mongooseLoader();
    console.log('Mongoose loaded!');

    let eventHandleService = new EventHandleService();
    eventHandleService.setup(mqttClient, wss);

    await expressLoader();
    console.log('Express loaded!')
}