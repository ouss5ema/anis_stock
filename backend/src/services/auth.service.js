const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const { env } = require('../config/env');
const { ApiError } = require('../utils/ApiError');
const { serializeUser } = require('../utils/serialize');
const userRepository = require('../repositories/user.repository');

const SALT_ROUNDS = 12;

function signToken(user) {
  return jwt.sign(
    {
      sub: user.id,
      email: user.email,
      role: user.role,
    },
    env.JWT_SECRET,
    { expiresIn: env.JWT_EXPIRES_IN }
  );
}

async function register({ name, email, password }) {
  if (!env.ALLOW_REGISTER) {
    throw ApiError.forbidden('Registration is disabled');
  }

  const existing = await userRepository.findByEmail(email);
  if (existing) {
    throw ApiError.conflict('An account with this email already exists');
  }

  const passwordHash = await bcrypt.hash(password, SALT_ROUNDS);
  const user = await userRepository.create({
    name,
    email,
    passwordHash,
    role: 'USER',
  });

  const token = signToken(user);

  return {
    user: serializeUser(user),
    token,
  };
}

async function login({ email, password }) {
  const user = await userRepository.findByEmail(email);

  if (!user) {
    throw ApiError.unauthorized('Invalid email or password');
  }

  if (!user.isActive) {
    throw ApiError.forbidden('This account is inactive');
  }

  const matches = await bcrypt.compare(password, user.passwordHash);
  if (!matches) {
    throw ApiError.unauthorized('Invalid email or password');
  }

  return {
    user: serializeUser(user),
    token: signToken(user),
  };
}

async function getMe(userId) {
  const user = await userRepository.findById(userId);
  if (!user || !user.isActive) {
    throw ApiError.unauthorized('Account is inactive or no longer exists');
  }
  return serializeUser(user);
}

module.exports = {
  register,
  login,
  getMe,
};
