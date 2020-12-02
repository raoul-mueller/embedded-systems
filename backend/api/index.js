const Router = require('express').Router;
const user = require('./user');

module.exports = () => {
    const app = Router();

    user(app);

    return app;
}