function paginationMeta(total, page, pageSize) {
  return {
    total,
    page,
    pageSize,
    totalPages: Math.ceil(total / pageSize) || 1,
  };
}

module.exports = { paginationMeta };
