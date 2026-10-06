const { z } = require('zod');

const registerSchema = z.object({
  body: z.object({
    name: z.string().trim().min(2, 'Name must be at least 2 characters').max(120),
    email: z.string().trim().email('Invalid email').toLowerCase(),
    password: z.string().min(8, 'Password must be at least 8 characters').max(72),
  }),
});

const loginSchema = z.object({
  body: z.object({
    email: z.string().trim().email('Invalid email').toLowerCase(),
    password: z.string().min(1, 'Password is required'),
  }),
});

module.exports = { registerSchema, loginSchema };
