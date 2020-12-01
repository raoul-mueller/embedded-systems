const mqttLoader = require('./mqttLoader');
const mongooseLoader = require('./mongooseLoader');

module.exports = async () => {
    let mqttClient = await mqttLoader();
    console.log('MQTT Client loaded!');

    let mongooseDb = await mongooseLoader();
    console.log('Mongoose connected!');
}