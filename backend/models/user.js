const mongoose = require('mongoose');

// TODO real model
const user = new mongoose.Schema({
    username: {
        type: String,
        index: true
    },
    email: {
        type: String,
        index: true
    },
    password: {
        type: String
    },
    salt: {
        type: String
    }
});

module.exports = mongoose.model('User', user);