const { Router } = require('express');
const authController = require('../controllers/auth.controller');
const { validate } = require('../middlewares/validate.middleware');
const { authenticate } = require('../middlewares/auth.middleware');
const { authLimiter } = require('../middlewares/rateLimit.middleware');
const { registerSchema, loginSchema } = require('../validators/auth.validator');

const router = Router();
const limiter = authLimiter();

router.post('/register', limiter, validate(registerSchema), authController.register);
router.post('/login', limiter, validate(loginSchema), authController.login);
router.get('/me', authenticate, authController.me);

module.exports = router;
