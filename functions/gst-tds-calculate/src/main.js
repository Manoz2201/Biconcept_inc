export default async ({ req, res }) => {
  const { taxableValue = 0, contractValue = 0, isInterState = false } = JSON.parse(req.body || '{}');
  if (Number(contractValue) <= 250000) {
    return res.json({ applicable: false, reason: 'Contract value below ₹2,50,000 threshold' });
  }
  const cgstTds = isInterState ? 0 : Math.round(Number(taxableValue) * 1) / 100;
  const sgstTds = isInterState ? 0 : Math.round(Number(taxableValue) * 1) / 100;
  const igstTds = isInterState ? Math.round(Number(taxableValue) * 2) / 100 : 0;
  return res.json({
    applicable: true,
    isInterState,
    tdsRate: 2,
    cgstTds,
    sgstTds,
    igstTds,
    totalTds: Math.round((cgstTds + sgstTds + igstTds) * 100) / 100,
  });
};
