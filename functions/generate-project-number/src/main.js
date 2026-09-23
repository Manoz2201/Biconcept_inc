/**
 * Optional numbering helper. The Flutter app still stamps PRJ-{year}-{sequence}
 * from the created row's $sequence when this function is missing or fails.
 */
export default async ({ req, res }) => {
  const year = new Date().getUTCFullYear();
  let sequence = 0;
  try {
    const body = JSON.parse(req.body || '{}');
    sequence = Number(body.sequence ?? body.$sequence ?? 0);
  } catch {
    sequence = 0;
  }
  const padded = String(Math.max(0, Number.isFinite(sequence) ? sequence : 0)).padStart(4, '0');
  const projectNumber = `PRJ-${year}-${padded}`;
  return res.json({ projectNumber, year, sequence });
};
