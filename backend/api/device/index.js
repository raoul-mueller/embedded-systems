const Router = require('express').Router;
const userModel = require('../../models/user');
const deviceModel = require('../../models/device');
const { celebrate, Joi } = require('celebrate');

const route = Router();

module.exports = (app) => {
    app.use('/devices', route);

    route.get(
      '/',
      async (req, res, next) => {
          try {
              const devices = await deviceModel.find({}).exec();
              return res.json({ devices });
          } catch (e) {
              next(e);
          }
      }
    )

    route.post(
        '/',
        celebrate({
            body: Joi.object({
                user: Joi.object({
                    uuid: Joi.string()
                }),
                device: Joi.object({
                    uuid: Joi.string().required(),
                    name: Joi.string().required()
                }).required()
            })
        }),
        async (req, res, next) => {
            try {
                let device = await deviceModel.findOne({ uuid: req.body.device.uuid }).exec();

                if (device) {
                    if (req.body.user) {
                        await userModel.updateMany(
                            { device: device._id },
                            { device: null }
                        );
                    }

                    await deviceModel.findOneAndUpdate(
                        { uuid: device.uuid },
                        { name: req.body.device.name }
                    );
                } else {
                    device = new deviceModel({ ...req.body.device });
                    await device.save();
                }

                let user = await userModel.findOneAndUpdate(
                    req.body.user ? { uuid: req.body.user.uuid } : { device: device._id },
                    { device: device._id },
                    { new: true }
                ).populate('device');

                return res.status(200).json({ user });
            } catch (e) {
                return next(e);
            }
        },
    );
};

