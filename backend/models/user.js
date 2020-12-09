const mongoose = require('mongoose');
const Schema = mongoose.Schema;

const user = new Schema({
    _id: Schema.Types.ObjectId,
    uuid: String,
    realname: String,
    pictureUrl: String,
});

module.exports = mongoose.model('User', user);