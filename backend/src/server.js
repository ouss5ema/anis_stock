const { env } = require('./config/env');
const { prisma } = require('./config/prisma');
const { createApp } = require('./app');
const { logger } = require('./utils/logger');

const app = createApp();
let server;

async function start() {
  try {
    await prisma.$connect();
    server = app.listen(env.PORT, '0.0.0.0', () => {
      logger.info('Stock API listening', { port: env.PORT, env: env.NODE_ENV });
    });
  } catch (error) {
    logger.error('Failed to start server', { message: error.message });
    process.exit(1);
  }
}

async function shutdown() {
  if (server) {
    await new Promise((resolve) => {
      server.close(resolve);
    });
  }
  await prisma.$disconnect();
  process.exit(0);
}

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);

start();

