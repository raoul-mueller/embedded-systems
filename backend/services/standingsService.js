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
                start: { $gte: todayBegin },
                end: { $lte: todayEnd }
            }).exec();

            let userHighscoreChanged = false;
            for (const score of scoresToday) {
                this.addScoreToStanding(score, standing);
                if (score.score.current > user.highscore) {
                    user.highscore = score.score.current;
                    userHighscoreChanged = true;
                }
            }

            let yesterdayBegin = DateTime.utc().minus({ days: 1 }).startOf('day');

            let scoresYesterday = await scoreEntryModel.find({
                user: user._id,
                start: { $gte: yesterdayBegin },
                end: { $lte: todayBegin }
            }).exec();

            for (const score of scoresYesterday) {
                this.addScoreToStanding(score, standing, 'yesterday');
            }

            standings.standings.push(standing);

            if (userHighscoreChanged) {
                await user.save();
            }
        }

        standings.standings.sort((a, b) => a.score.current - b.score.current);

        return standings;
    }

    addScoreToStanding(score, standing, day = 'today') {
        let current = standing.score[day === 'today' ? 'current' : 'lastDay'];
        standing.score[day === 'today' ? 'current' : 'lastDay'] = Math.max(current, score.score);
        standing.score.hourly[day].push(score.score);

        current = standing.steps[day === 'today' ? 'current' : 'lastDay'];
        standing.steps[day === 'today' ? 'current' : 'lastDay'] = Math.max(current, score.steps);
        standing.steps.hourly[day].push(score.steps);

        current = standing.standing[day === 'today' ? 'current' : 'lastDay'];
        standing.standing[day === 'today' ? 'current' : 'lastDay'] = Math.max(current, score.standingMinutes);
        standing.standing.hourly[day].push(score.standingMinutes);

        current = standing.outside[day === 'today' ? 'current' : 'lastDay'];
        standing.outside[day === 'today' ? 'current' : 'lastDay'] = Math.max(current, score.outsideMinutes);
        standing.outside.hourly[day].push(score.outsideMinutes);
    }

    copyObject(obj) {
        return JSON.parse(JSON.stringify(obj));
    }
}

module.exports = StadingsService;