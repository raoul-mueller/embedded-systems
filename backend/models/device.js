const mongoose = require('mongoose');
const Schema = mongoose.Schema;

const device = new Schema({
    _id: Schema.Types.ObjectId,
    uuid: String,
    name: String
});

module.exports = mongoose.model('Device', device);