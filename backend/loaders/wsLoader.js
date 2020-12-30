const ws = require('ws');

module.exports = async () => {
    return new ws.Server({port: 9002});
}