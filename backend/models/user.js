const mongoose = require('mongoose');
const Schema = mongoose.Schema;
const pictureUrlPrefix = require('../plugins/pictureUrlPrefix');

const user = new Schema({
    uuid: String,
    realname: String,
    pictureUrl: String,
    highscore: Number,
    device: { type: Schema.Types.ObjectId, ref: 'Device' }
});

user.plugin(pictureUrlPrefix);

module.exports = mongoose.model('User', user);