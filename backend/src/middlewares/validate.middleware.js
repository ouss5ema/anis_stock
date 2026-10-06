function validate(schema) {
  return (req, _res, next) => {
    try {
      const parsed = schema.parse({
        body: req.body,
        params: req.params,
        query: req.query,
      });

      req.validated = parsed;
      if (parsed.body) {
        req.body = parsed.body;
      }

      return next();
    } catch (error) {
      return next(error);
    }
  };
}

module.exports = { validate };
