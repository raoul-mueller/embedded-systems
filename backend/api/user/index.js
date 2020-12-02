const Router = require('express').Router;
const userModel = require('../../models/user');

const route = Router();

module.exports = (app) => {
  app.use('/users', route);

  route.get('/all', async (req, res) => {
    let users = await userModel.find();
    return res.json({ users }).status(200);
  });
};