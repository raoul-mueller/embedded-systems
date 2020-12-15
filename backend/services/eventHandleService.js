const deviceModel = require('../models/device');
const userModel = require('../models/user');
const scoreEntryModel = require('../models/scoreEntry');
const StadingsService = require('./standingsService');
const { DateTime, Interval } = require('luxon');
const util = require('util');

class EventHandleService {
    constructor() {
        this.stadingsService = new StadingsService();
    }

    setup(mqtt, wss) {
        mqtt.on('message', async (topic, message) => {
            if (topic !== 'ES/WS20/gruppe7/events') {
                return;
            }

            await this.handleEvent(message);

            let standings = await this.stadingsService.generateStandings();
            //console.log(util.inspect(standings, false, null, true));

            wss.clients.forEach((client) => {
                if (client.readyState === WebSocket.OPEN) {
                    client.send(JSON.stringify(standings));
                }
            });
        });
    }

    async handleEvent(message) {
        if (!this.isJson(message)) {
            return;
        }

        const event = JSON.parse(message);
        
        //fetch device
        const device = await deviceModel.findOne({
            uuid: event.boardID
        }).exec();

        if (!device) {
            console.log(`Device with board id ${event.boardID} not found`);
            return;
        }

        //fetch user by device
        const user = await userModel.findOne({
            device: device._id
        }).exec();

        if (!user) {
            console.log(`User for device ${device._id} not found`);
            return;
        }

        let now = DateTime.utc();

        //fetch current scoreEntry
        let scoreEntry = await scoreEntryModel.findOne({
            user: user._id,
            start: { $lte: now.toMillis() },
            end: { $gte: now.toMillis() }
        }).exec();

        if (!scoreEntry) {
            //create new entry if not found
            let hourBegin = DateTime.utc().startOf('hour');
            let hourEnd = DateTime.utc().endOf('hour');
            let prevHourBegin = hourBegin.minus({ hours: 1 });

            let prevScoreEntry = null;
            if (prevHourBegin.day === hourBegin.day) {
                prevScoreEntry = await scoreEntryModel.findOne({
                    user: user._id,
                    start: { $gte: prevHourBegin.toMillis() },
                    end: { $lte: hourBegin.toMillis() }
                }).exec();
            }

            const scoreEntryData = {
                user: user._id,
                start: hourBegin.toMillis(),
                end: hourEnd.toMillis(),
                score: prevScoreEntry ? prevScoreEntry.score : 0,
                steps: prevScoreEntry ? prevScoreEntry.steps : 0,
                standingMinutes: prevScoreEntry ? prevScoreEntry.standingMinutes : 0,
                outsideMinutes: prevScoreEntry ? prevScoreEntry.outsideMinutes : 0, 
                lastUpdate: prevScoreEntry ? prevScoreEntry.lastUpdate : now.toMillis()
            };
            
            scoreEntry = new scoreEntryModel(scoreEntryData);
            await scoreEntry.save();
        }

        //add standing/outside minutes
        let lastUpdate = DateTime.fromMillis(scoreEntry.lastUpdate.getTime()).toUTC();
        let minutesSinceLastUpdate = Interval.fromDateTimes(lastUpdate, now).length('minutes');
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
        scoreEntry.lastUpdate = now.toMillis();

        //calc new score
        const newScore = scoreEntry.steps * 0.5 + scoreEntry.standingMinutes + scoreEntry.outsideMinutes;
        scoreEntry.score = Math.ceil(newScore);

        await scoreEntry.save();
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