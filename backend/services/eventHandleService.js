const deviceModel = require('../models/device');
const userModel = require('../models/user');
const scoreEntryModel = require('../models/scoreEntry');
const StadingsService = require('./standingsService');
const { DateTime, Interval } = require('luxon');
const util = require('util');
const WebSocket = require('ws');

class EventHandleService {
    constructor() {
        this.stadingsService = new StadingsService();
    }

    setup(mqtt, wss) {
        wss.on('connection', (ws) => {
            let standings = await this.stadingsService.generateStandings();
            client.send(JSON.stringify(standings));
        });

        mqtt.on('message', async (topic, message) => {
            if (topic !== 'ES/WS20/gruppe7/events') {
                return;
            }

            await this.handleEvent(message);

            let standings = await this.stadingsService.generateStandings();
            console.log(util.inspect(standings, false, null, true));

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
            start: { $lte: now },
            end: { $gte: now }
        }).exec();

        if (!scoreEntry) {
            //create new entry if not found
            let hourBegin = DateTime.utc().startOf('hour');
            let hourEnd = DateTime.utc().endOf('hour');

            let prevScoreEntry = await scoreEntryModel.findOne({
                user: user._id,
            }).sort('-start').exec();

            let prevScoreBegin = DateTime.fromMillis(prevScoreEntry.start.getTime()).toUTC();
            if (prevScoreBegin.day !== hourBegin.day) {
                prevScoreEntry = null;
            }

            const scoreEntryData = {
                user: user._id,
                start: hourBegin,
                end: hourEnd,
                score: prevScoreEntry ? prevScoreEntry.score : 0,
                steps: prevScoreEntry ? prevScoreEntry.steps : 0,
                standingMinutes: prevScoreEntry ? prevScoreEntry.standingMinutes : 0,
                outsideMinutes: prevScoreEntry ? prevScoreEntry.outsideMinutes : 0, 
                lastUpdate: now
            };
            
            scoreEntry = new scoreEntryModel(scoreEntryData);
            await scoreEntry.save();
        }

        //add standing/outside minutes
        let lastUpdate = DateTime.fromJSDate(scoreEntry.lastUpdate).toUTC();
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
        const newScore = scoreEntry.steps * 0.5 + (scoreEntry.standingMinutes * 2) + (scoreEntry.outsideMinutes * 2);
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