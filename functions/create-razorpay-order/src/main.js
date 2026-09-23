export default async ({ req, res, log }) => {
  const keyId = process.env.RAZORPAY_KEY_ID;
  const keySecret = process.env.RAZORPAY_KEY_SECRET;
  if (!keyId || !keySecret) {
    return res.json({ error: 'Razorpay secrets are not configured' }, 400);
  }
  let payload = {};
  try {
    payload = JSON.parse(req.body || '{}');
  } catch {
    payload = {};
  }
  const amountPaise = Math.round(Number(payload.amount || 0) * 100);
  const auth = Buffer.from(`${keyId}:${keySecret}`).toString('base64');
  const response = await fetch('https://api.razorpay.com/v1/orders', {
    method: 'POST',
    headers: { Authorization: `Basic ${auth}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      amount: amountPaise,
      currency: payload.currency || 'INR',
      receipt: payload.receipt || `rcpt_${Date.now()}`,
    }),
  });
  const body = await response.json();
  log(`Razorpay order ${body.id || 'failed'}`);
  return res.json({ orderId: body.id, raw: body }, response.ok ? 200 : 400);
};
