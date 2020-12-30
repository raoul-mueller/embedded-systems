async function startServer() {
  await require('./loaders')();
}

startServer();