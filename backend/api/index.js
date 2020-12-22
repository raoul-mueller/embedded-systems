const Router = require('express').Router;
const user = require('./user');
const image = require('./image');

module.exports = () => {
    const app = Router();

    user(app);
    image(app);

    return app;
}