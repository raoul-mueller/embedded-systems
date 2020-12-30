const Router = require('express').Router;
const user = require('./user');
const image = require('./image');
const device = require('./device');

module.exports = () => {
    const app = Router();

    user(app);
    image(app);
    device(app);

    return app;
}