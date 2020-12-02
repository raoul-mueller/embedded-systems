const mqttLoader = require('./mqttLoader');
const mongooseLoader = require('./mongooseLoader');
const expressLoader = require('./expressLoader');

module.exports = async () => {
    let mqttClient = await mqttLoader();
    console.log('MQTT Client loaded!');

    let mongooseDb = await mongooseLoader();
    console.log('Mongoose loaded!');

    await expressLoader();
    console.log('Express loaded!')
}