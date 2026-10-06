async function nextReference(tx, model, prefix) {
  const day = new Date().toISOString().slice(0, 10).replaceAll('-', '');
  const stem = `${prefix}-${day}-`;

  await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext(${stem}))`;

  const last = await tx[model].findFirst({
    where: { referenceNumber: { startsWith: stem } },
    orderBy: { referenceNumber: 'desc' },
    select: { referenceNumber: true },
  });

  const sequence = last ? Number(last.referenceNumber.slice(stem.length)) + 1 : 1;
  return `${stem}${String(sequence).padStart(4, '0')}`;
}

module.exports = { nextReference };
