function notFoundHandler(req, res) {
  return res.status(404).json({
    success: false,
    message: `Route ${req.method} ${req.originalUrl} not found`,
    errors: [],
  });
}

module.exports = { notFoundHandler };
