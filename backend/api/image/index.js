const Router = require('express').Router;
const userModel = require('../../models/user');
const upload = require('../../middleware/upload');
const resize = require('../../middleware/resize');
const { DateTime } = require('luxon');

const route = Router();

module.exports = (app) => {
  app.use('/images', route);

  route.post(
    '/',
    upload.single('image'),
    resize,
    async (req, res, next) => {
      try {
        let user = await userModel.findOneAndUpdate(
            { uuid: req.body.uuid },
            {
                pictureUrl: req.file.filename,
                pictureUpdated: DateTime.utc()
            },
            { new: true }
        );
        return res.status(200).json({ user });
      } catch (e) {
        return next(e);
      }
    },
  );
};