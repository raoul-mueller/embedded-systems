const multer = require('multer');

let storage = multer.diskStorage({
    destination: __dirname + '/../uploads',
})

module.exports = multer({ storage: storage });