const userModel = require('../models/user');
const scoreEntryModel = require('../models/scoreEntry');

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
        
        let now = Date.now();

        let scoreEntry = scoreEntryModel.findOne({
            start: { $gte: now },
            end: { $lte: now }
        }).exec();

        if (!scoreEntry) {
            let hourBegin = new Date();
            let hourEnd = new Date();
    
            hourBegin.setMinutes(0);
            hourBegin.setSeconds(0);
    
            let nextHour = hourBegin.getHours + 1;
            nextHour = nextHour > 23 ? 0 : nextHour;
    
            hourEnd.setHours(nextHour);
            hourEnd.setMinutes(0);
            hourEnd.setSeconds(0);

            //create entry
        }

        
        


        return {};
    }
}

module.exports = EventHandleService;