const jwt = require('jsonwebtoken');
const { env } = require('../config/env');
const { prisma } = require('../config/prisma');
const { ApiError } = require('../utils/ApiError');

function authenticate(req, _res, next) {
  const header = req.headers.authorization;

  if (!header || !header.startsWith('Bearer ')) {
    return next(ApiError.unauthorized('Missing or invalid authorization header'));
  }

  const token = header.slice(7);

  try {
    const payload = jwt.verify(token, env.JWT_SECRET);
    req.user = {
      id: payload.sub,
      email: payload.email,
      role: payload.role,
    };
    return next();
  } catch {
    return next(ApiError.unauthorized('Invalid or expired token'));
  }
}

function requireRole(...roles) {
  return (req, _res, next) => {
    if (!req.user || !roles.includes(req.user.role)) {
      return next(ApiError.forbidden());
    }
    return next();
  };
}

async function loadActiveUser(req, _res, next) {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.user.id },
      select: {
        id: true,
        email: true,
        name: true,
        role: true,
        isActive: true,
      },
    });

    if (!user || !user.isActive) {
      return next(ApiError.unauthorized('Account is inactive or no longer exists'));
    }

    req.user = {
      id: user.id,
      email: user.email,
      role: user.role,
      name: user.name,
    };
    req.currentUser = user;
    return next();
  } catch (error) {
    return next(error);
  }
}

const authenticateActive = [authenticate, loadActiveUser];

module.exports = { authenticate, requireRole, loadActiveUser, authenticateActive };
