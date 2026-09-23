export default async ({ req, res, log, error }) => {
  const { invoiceId, payload } = JSON.parse(req.body || '{}');
  const base = process.env.IRP_BASE_URL;
  if (!base || !process.env.IRP_CLIENT_ID || !process.env.IRP_CLIENT_SECRET) {
    log('IRP credentials missing — set IRP_* on this Function only.');
    return res.json({
      success: false,
      error: 'IRP credentials are not configured on generate-einvoice-irn',
      invoiceId,
    });
  }
  try {
    const authResponse = await fetch(`${base}/auth`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        client_id: process.env.IRP_CLIENT_ID,
        client_secret: process.env.IRP_CLIENT_SECRET,
        username: process.env.IRP_USERNAME,
        password: process.env.IRP_PASSWORD,
        grant_type: 'client_credentials',
      }),
    });
    const auth = await authResponse.json();
    const irnResponse = await fetch(`${base}/invoice`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${auth.access_token}`,
      },
      body: JSON.stringify({ payload }),
    });
    const irn = await irnResponse.json();
    if (!irn.Irn) return res.json({ success: false, error: irn.error || 'IRN generation failed', invoiceId });
    return res.json({
      success: true,
      irn: irn.Irn,
      ackNumber: irn.AckNo,
      ackDate: irn.AckDt,
      qrCode: irn.SignedQRCode,
      signedInvoice: irn.SignedInvoice,
    });
  } catch (err) {
    error(err);
    return res.json({ success: false, error: String(err), invoiceId });
  }
};
