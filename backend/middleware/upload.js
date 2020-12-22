const multer = require('multer');
const mime = require('mime-types');

let storage = multer.diskStorage({
    destination: __dirname + '/../uploads',
    // filename: (req, file, cb) => {
    //     const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    //     cb(null, file.fieldname + '-' + uniqueSuffix);
    // }
})

module.exports = multer({ storage: storage });