import { createHmac } from 'node:crypto';

export default async ({ req, res }) => {
  const secret = process.env.RAZORPAY_KEY_SECRET;
  if (!secret) return res.json({ valid: false, error: 'missing secret' }, 400);
  let payload = {};
  try {
    payload = JSON.parse(req.body || '{}');
  } catch {
    payload = {};
  }
  const body = `${payload.orderId}|${payload.paymentId}`;
  const expected = createHmac('sha256', secret).update(body).digest('hex');
  return res.json({ valid: expected === payload.signature });
};
