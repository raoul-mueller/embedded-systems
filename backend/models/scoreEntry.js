const mongoose = require('mongoose');
const Schema = mongoose.Schema;

const scoreEntry = new Schema({
    user: { type: Schema.Types.ObjectId, ref: 'User' },
    start: Date,
    end: Date,
    score: Number,
    steps: Number,
    standingMinutes: Number,
    outsideMinutes: Number,
    lastUpdate: Date
});

module.exports = mongoose.model('ScoreEntry', scoreEntry);