const intervalInSeconds = process.argv[2];
const boardID = process.argv[3];

if (!intervalInSeconds) {
    console.error('Please specify an interval');
    return;
}

if (!boardID) {
    console.error('Please specify a board ID');
    return;
}

const mqtt = require('mqtt');
const config = require('./config');

const client  = mqtt.connect(config.mqttUrl, {
    username: config.mqttUser,
    password: config.mqttPassword,
});

function getRandomInt(max) {
    return Math.floor(Math.random() * Math.floor(max));
}

const maxSteps = 10;
const standingThreshold = 65;
const outsideThreshold = 65;

function publishFakeEvent() {
    const event = {
        boardID: boardID,
        standing: getRandomInt(100) >= standingThreshold,
        stepsSinceLastUpdate: getRandomInt(maxSteps),
        outside: getRandomInt(100) >= outsideThreshold
    };

    client.publish(config.mqttChannelBase + config.mqttEventChannel, JSON.stringify(event));
    console.log(`Published Event ${JSON.stringify(event)}`);
}

publishFakeEvent();
setInterval(publishFakeEvent, intervalInSeconds * 1000);