const userModel = require('../models/user');

class EventHandleService {
    setup(mqtt, wss) {
        mqtt.on('message', async (topic, message) => {
            console.log(topic);
            console.log(message.toString());

            let standings = await handleEvent(message);
            
            wss.clients.forEach((client) => {
                if (client.readyState === WebSocket.OPEN) {
                    client.send(JSON.stringify(standings));
                }
            });
        });
    }

    async handleEvent(message) {
        let event = JSON.parse(message);

        //...

        return {};
    }
}

module.exports = EventHandleService;