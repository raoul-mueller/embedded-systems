const Router = require('express').Router;
const userModel = require('../../models/user');
const { celebrate, Joi } = require('celebrate');

const route = Router();

module.exports = (app) => {
  app.use('/users', route);

  route.post(
    '/',
    celebrate({
      body: Joi.object({
        uuid: Joi.string().required(),
        realname: Joi.string().required()
      })
    }),
    async (req, res, next) => {
      try {
        let user = new userModel({
          ...req.body,
          highscore: 0
        });

        await user.save();
        return res.status(200).json({ user });
      } catch (e) {
        return next(e);
      }
    },
  );

  route.put(
    '/',
    celebrate({
      body: Joi.object({
        uuid: Joi.string().required(),
        realname: Joi.string().required()
      })
    }),
    async (req, res, next) => {
      try {
        let user = await userModel.findOneAndUpdate(
          { uuid: req.body.uuid },
          { realname: req.body.realname }
        );
        user = await userModel.findOne({ uuid: req.body.uuid });
        return res.status(200).json({ user });
      } catch (e) {
        return next(e);
      }
    },
  );
};

