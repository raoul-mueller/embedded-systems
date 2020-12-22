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

    app.use('/static', express.static(__dirname + '/../images'));

    app.use((req, res, next) => {
        const err = new Error('Not Found');
        err['status'] = 404;
        next(err);
    });

    app.use((err, req, res, next) => {
        res.status(err.status || 500);
        res.json({
            errors: {
                message: err.message,
            },
        });
    });

    app.listen(config.expressPort, () => {
        console.log(`Listening on ${config.expressPort}`);
    });
};