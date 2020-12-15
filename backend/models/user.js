const mongoose = require('mongoose');
const Schema = mongoose.Schema;

const user = new Schema({
    uuid: String,
    realname: String,
    pictureUrl: String,
    highscore: Number,
    device: { type: Schema.Types.ObjectId, ref: 'Device' }
});

module.exports = mongoose.model('User', user);