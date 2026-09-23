export default async ({ req, res, log, error }) => {
  const { ewayBillId, payload } = JSON.parse(req.body || '{}');
  const base = process.env.EWB_BASE_URL;
  if (!base || !process.env.EWB_CLIENT_ID || !process.env.EWB_CLIENT_SECRET) {
    log('EWB credentials missing — set EWB_* on this Function only.');
    return res.json({
      success: false,
      error: 'E-way bill credentials are not configured on generate-ewaybill',
      ewayBillId,
    });
  }
  try {
    const authResponse = await fetch(`${base}/auth`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        username: process.env.EWB_USERNAME,
        password: process.env.EWB_PASSWORD,
        client_id: process.env.EWB_CLIENT_ID,
        client_secret: process.env.EWB_CLIENT_SECRET,
      }),
    });
    const auth = await authResponse.json();
    const ewbResponse = await fetch(`${base}/ewaybill`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${auth.access_token}`,
      },
      body: JSON.stringify(payload),
    });
    const ewb = await ewbResponse.json();
    if (!ewb.ewayBillNo) return res.json({ success: false, error: ewb.error || 'EWB generation failed', ewayBillId });
    const distance = Number(payload?.distance || 0);
    const odc = payload?.vehicleType === 'over_dimensional_cargo';
    const days = Math.max(1, Math.ceil(distance / (odc ? 20 : 200)));
    const validUntil = new Date();
    validUntil.setDate(validUntil.getDate() + days);
    return res.json({ success: true, ewayBillNumber: ewb.ewayBillNo, validUntil: validUntil.toISOString() });
  } catch (err) {
    error(err);
    return res.json({ success: false, error: String(err), ewayBillId });
  }
};
