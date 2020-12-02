const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
const routes = require('../api');
const config = require('../config');

module.exports = async () => {
    const app = express();

    app.get('/status', (req, res) => {
        res.status(200).end();
    });

    app.use(cors());
    app.use(bodyParser.json());
    app.use(config.expressApiPrefix, routes());

    app.listen(config.expressPort, () => {
        console.log(`Listening on ${config.expressPort}`);
    });
};