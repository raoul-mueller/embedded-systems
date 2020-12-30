const sharp = require('sharp');
const fs = require('fs');

module.exports = async (req, res, next) => {
    if (!req.file) {
        return next(new Error('image missing'));
    }
    
    const filename = `${req.body.uuid}.jpeg`;
    await sharp(req.file.path)
            .resize(128, 128)
            .toFormat('jpeg')
            .jpeg({ quality: 90 })
            .toFile(__dirname + '/../images/' + filename);
    fs.unlinkSync(req.file.path);

    req.file.filename = filename;

    return next();
};