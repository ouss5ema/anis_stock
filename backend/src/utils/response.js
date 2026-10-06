function success(res, data = null, message = 'Operation successful', statusCode = 200) {
  return res.status(statusCode).json({
    success: true,
    data,
    message,
  });
}

function created(res, data = null, message = 'Resource created') {
  return success(res, data, message, 201);
}

module.exports = { success, created };
