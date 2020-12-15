const userModel = require('../models/user');
const scoreEntryModel = require('../models/scoreEntry');
const { DateTime } = require('luxon');

class StadingsService {
    async generateStandings() {
        let users = await userModel.find({});
        let standings = { standings: [] };

        for (const user of users) {
            let scoreDetail = {
                current: 0,
                lastDay: 0,
                hourly : {
                    today: [],
                    yesterday: []
                }
            };

            let standing = {
                user,
                score: { ...this.copyObject(scoreDetail) },
                steps: { ...this.copyObject(scoreDetail) },
                standing: { ...this.copyObject(scoreDetail) },
                outside: { ...this.copyObject(scoreDetail) }
            };

            let todayBegin = DateTime.utc().startOf('day');
            let todayEnd = DateTime.utc().endOf('day');

            let scoresToday = await scoreEntryModel.find({
                user: user._id,
                start: { $gte: todayBegin.toMillis() },
                end: { $lte: todayEnd.toMillis() }
            }).exec();

            for (const score of scoresToday) {
                this.addScoreToStanding(score, standing);
            }

            let yesterdayBegin = DateTime.utc().minus({ days: 1 }).startOf('day');

            let scoresYesterday = await scoreEntryModel.find({
                user: user._id,
                start: { $gte: yesterdayBegin.toMillis() },
                end: { $lte: todayBegin.toMillis() }
            }).exec();

            for (const score of scoresYesterday) {
                this.addScoreToStanding(score, standing, 'yesterday');
            }

            standings.standings.push(standing);
        }

        standings.standings.sort((a, b) => a.score.current - b.score.current);

        return standings;
    }

    addScoreToStanding(score, standing, day = 'today') {
        standing.score[day === 'today' ? 'current' : 'lastDay'] = score.score;
        standing.score.hourly[day].push(score.score);

        standing.steps[day === 'today' ? 'current' : 'lastDay'] = score.steps;
        standing.steps.hourly[day].push(score.steps);

        standing.standing[day === 'today' ? 'current' : 'lastDay'] = score.standingMinutes;
        standing.standing.hourly[day].push(score.standingMinutes);

        standing.outside[day === 'today' ? 'current' : 'lastDay'] = score.outsideMinutes;
        standing.outside.hourly[day].push(score.outsideMinutes);
    }

    copyObject(obj) {
        return JSON.parse(JSON.stringify(obj));
    }
}

module.exports = StadingsService;