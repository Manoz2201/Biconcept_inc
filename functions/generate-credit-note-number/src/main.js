export default async ({ req, res }) => {
  const now = new Date();
  const startYear = now.getUTCMonth() + 1 >= 4 ? now.getUTCFullYear() : now.getUTCFullYear() - 1;
  const fy = `${startYear}-${String((startYear + 1) % 100).padStart(2, '0')}`;
  let sequence = 0;
  try {
    const body = JSON.parse(req.body || '{}');
    sequence = Number(body.sequence ?? body.$sequence ?? 0);
  } catch {
    sequence = 0;
  }
  const padded = String(Math.max(0, Number.isFinite(sequence) ? sequence : 0)).padStart(4, '0');
  return res.json({ creditNoteNumber: `CN/${fy}/${padded}`, financialYear: fy, sequence });
};
