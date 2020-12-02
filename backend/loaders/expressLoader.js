const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
const routes = require('../api');

module.exports = async () => {
    const app = express();

    app.get('/status', (req, res) => {
        res.status(200).end();
    });

    app.use(cors());
    app.use(bodyParser.json());
    app.use('/api/v1', routes());

    app.listen(9001, () => {
        console.log('Listening on 9001');
    });
};