const userModel = require('../models/user');
const scoreEntryModel = require('../models/scoreEntry');
const { DateTime } = require('luxon');

class StadingsService {
    async generateStandings() {
        let users = await userModel.find({});
        let standings = { standings: [] };

        for (const user of users) {
            let standing = await this.generateStandingForUser(user);
            standings.standings.push(standing);
        }

        standings.standings.sort((a, b) => a.score.current - b.score.current);

        return standings;
    }

    async generateStandingForUser(user) {
        let scoreDetail = {
            current: 0,
            lastDay: 0,
            hourly : {
                today: Array.from({length: 24}, () => 0),
                yesterday: Array.from({length: 24}, () => 0)
            }
        };

        let standing = {
            user,
            score: { ...this.copyObject(scoreDetail) },
            steps: { ...this.copyObject(scoreDetail) },
            standing: { ...this.copyObject(scoreDetail) },
            outside: { ...this.copyObject(scoreDetail) }
        };

        let todayBegin = DateTime.local().startOf('day').toUTC();
        let todayEnd = DateTime.local().endOf('day').toUTC();

        let scoresToday = await scoreEntryModel.find({
            user: user._id,
            start: { $gte: todayBegin },
            end: { $lte: todayEnd }
        }).exec();

        let userHighscoreChanged = false;
        for (const score of scoresToday) {
            this.addScoreToStanding(score, standing);
            if (score.score > (user.highscore || 0)) {
                user.highscore = score.score;
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

        for (let key of Object.keys(standing)) {
            if (key !== 'user') {
                const maxScore = standing[key].current;

                for (let day of Object.keys(standing[key].hourly)) {
                    let curScore = 0;

                    for (let [i, s] of standing[key].hourly[day].entries()) {
                        if (s >= maxScore) {
                            break;
                        }
                        if (s > curScore) {
                            curScore = s;
                        }
                        if (s < curScore) {
                            standing[key].hourly[day][i] = curScore;
                        }
                    }
                }
            }
        }

        if (userHighscoreChanged) {
            await user.save();
        }

        return standing;
    }

    addScoreToStanding(score, standing, day = 'today') {
        let scoreHour = DateTime.fromJSDate(score.start).toLocal().hour - 1;

        this.addScoreTypeToStanding(standing, day, scoreHour, 'score', score.score);
        this.addScoreTypeToStanding(standing, day, scoreHour, 'steps', score.steps);
        this.addScoreTypeToStanding(standing, day, scoreHour, 'standing', score.standingMinutes);
        this.addScoreTypeToStanding(standing, day, scoreHour, 'outside', score.outsideMinutes);
    }

    addScoreTypeToStanding(standing, day, hour, type, score) {
        let current = standing[type][day === 'today' ? 'current' : 'lastDay'];
        standing[type][day === 'today' ? 'current' : 'lastDay'] = Math.max(current, score);
        standing[type].hourly[day][hour] = score;
    }

    copyObject(obj) {
        return JSON.parse(JSON.stringify(obj));
    }
}

module.exports = StadingsService;