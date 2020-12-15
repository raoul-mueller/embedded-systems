const mongoose = require('mongoose');
const config = require('./config');
const userModel = require('./models/user');
const deviceModel = require('./models/device');
const { v4: uuidv4 } = require('uuid');
var random_name = require('node-random-name');

async function createUser() {
    const connection = await mongoose.connect(config.databaseURL, {
        useNewUrlParser: true,
        useUnifiedTopology: true,
        useCreateIndex: true
    });

    const device = new deviceModel({
        uuid: uuidv4(),
        name: 'Test Device'
    });
    
    await device.save();
    
    const user = new userModel({
        realname: random_name(),
        uuid: uuidv4(),
        device: device._id
    });

    await user.save();

    connection.connection.close();

    console.log(`User with ID ${user._id} and device with BoardID ${device.uuid} created!`);
}

createUser();
