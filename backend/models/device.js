const mongoose = require('mongoose');
const Schema = mongoose.Schema;

const device = new Schema({
    uuid: String,
    name: String
});

module.exports = mongoose.model('Device', device);