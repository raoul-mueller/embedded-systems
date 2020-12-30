const dotenv = require('dotenv');

process.env.NODE_ENV = process.env.NODE_ENV || 'development';

const envFound = dotenv.config();
if (envFound.error) {
  throw new Error("Couldn't find .env file");
}

module.exports = {
  databaseURL: process.env.DATABASE_URL,

  mqttUrl: process.env.MQTT_URL,
  mqttUser: process.env.MQTT_USER,
  mqttPassword: process.env.MQTT_PASSWORD,
  mqttChannel: process.env.MQTT_CHANNEL,

  expressPort: process.env.EXPRESS_PORT,
  expressApiPrefix: process.env.EXPRESS_API_PREFIX,

  staticUrl: process.env.STATIC_URL
};