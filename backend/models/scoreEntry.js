const mongoose = require('mongoose');
const Schema = mongoose.Schema;

const scoreEntry = new Schema({
    _id: Schema.Types.ObjectId,
    user: { type: Schema.Types.ObjectId, ref: 'User' },
    start: String,
    end: String,
    score: Number,
    lastStanding: Boolean,
    lastOutside: Boolean
});

module.exports = mongoose.model('ScoreEntry', scoreEntry);