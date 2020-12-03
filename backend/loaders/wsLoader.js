const ws = require('ws');

module.exports = async () => {
    const wss = new ws.Server({ port: 9002 });
    return wss;
}