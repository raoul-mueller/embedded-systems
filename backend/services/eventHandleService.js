const deviceModel = require('../models/device');
const userModel = require('../models/user');
const scoreEntryModel = require('../models/scoreEntry');

class EventHandleService {
    setup(mqtt, wss) {
        mqtt.on('message', async (topic, message) => {
            if (topic !== 'ES/WS20/gruppe7/events') {
                return;
            }

            let standings = await this.handleEvent(message);
            if (standings !== {}) {
                wss.clients.forEach((client) => {
                    if (client.readyState === WebSocket.OPEN) {
                        client.send(JSON.stringify(standings));
                    }
                });
            }
        });
    }

    async handleEvent(message) {
        if (!this.isJson(message)) {
            return {};
        }

        const event = JSON.parse(message);
        
        //fetch device
        const device = await deviceModel.findOne({
            uuid: event.boardID
        }).exec();

        if (!device) {
            console.log(`Device with board id ${event.boardID} not found`);
            return {};
        }

        //fetch user by device
        const user = await userModel.findOne({
            device: device._id
        }).exec();

        if (!user) {
            console.log(`User for device ${device._id} not found`);
            return {};
        }

        let now = new Date(),
            nowMillis = now.getTime();

        //fetch current scoreEntry
        let scoreEntry = await scoreEntryModel.findOne({
            user: user._id,
            start: { $lte: now },
            end: { $gte: now }
        }).exec();

        if (!scoreEntry) {
            //create new entry if not found
            let hourBegin = new Date();
            let hourEnd = new Date();
            let prevHourBegin = new Date();
    
            hourBegin.setMinutes(0);
            hourBegin.setSeconds(0);
            hourBegin.setMilliseconds(0);
    
            let nextHour = hourBegin.getHours() + 1;
            nextHour = nextHour > 23 ? 0 : nextHour;

            hourEnd.setHours(nextHour);
            hourEnd.setMinutes(0);
            hourEnd.setSeconds(0);
            hourEnd.setMilliseconds(0);

            let prevHour = hourBegin.getHours() - 1;

            let prevScoreEntry = null;
            if (prevHour >= 0) {
                prevHourBegin.setHours(prevHour);
                prevHourBegin.setMinutes(0);
                prevHourBegin.setSeconds(0);
                prevHourBegin.setMilliseconds(0);

                prevScoreEntry = await scoreEntryModel.findOne({
                    user: user._id,
                    start: { $lte: prevHourBegin },
                    end: { $gte: hourBegin }
                }).exec();
            }

            const scoreEntryData = {
                user: user._id,
                start: hourBegin.getTime(),
                end: hourEnd.getTime(),
                score: prevScoreEntry ? prevScoreEntry.score : 0,
                steps: prevScoreEntry ? prevScoreEntry.steps : 0,
                standingMinutes: prevScoreEntry ? prevScoreEntry.standingMinutes : 0,
                outsideMinutes: prevScoreEntry ? prevScoreEntry.outsideMinutes : 0, 
                lastUpdate: prevScoreEntry ? prevScoreEntry.lastUpdate : now
            };
            scoreEntry = new scoreEntryModel(scoreEntryData);
            await scoreEntry.save();
        }

        //add standing/outside minutes
        let minutesSinceLastUpdate = (nowMillis - scoreEntry.lastUpdate) / 1000 / 60;
        if (event.standing) {
            scoreEntry.standingMinutes += minutesSinceLastUpdate;
            scoreEntry.standingMinutes = Number(scoreEntry.standingMinutes).toFixed(2);
        }
        if (event.outside) {
            scoreEntry.outsideMinutes += minutesSinceLastUpdate;
            scoreEntry.outsideMinutes = Number(scoreEntry.outsideMinutes).toFixed(2);
        }

        //update entry
        scoreEntry.steps += event.stepsSinceLastUpdate;
        scoreEntry.lastUpdate = nowMillis;

        //calc new score
        const newScore = scoreEntry.steps * 0.5 + scoreEntry.standingMinutes + scoreEntry.outsideMinutes;
        scoreEntry.score = Math.ceil(newScore);

        await scoreEntry.save();
        
        return {};
    }

    isJson(string) {
        try {
            JSON.parse(string);
        } catch (e) {
            return false;
        }
        return true;
    }
}

module.exports = EventHandleService;