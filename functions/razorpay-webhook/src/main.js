import { createHmac } from 'node:crypto';

export default async ({ req, res, log }) => {
  const secret = process.env.RAZORPAY_WEBHOOK_SECRET;
  const signature = req.headers['x-razorpay-signature'];
  if (!secret || !signature) return res.json({ ok: false }, 400);
  const expected = createHmac('sha256', secret).update(req.body || '').digest('hex');
  if (expected !== signature) return res.json({ ok: false, error: 'invalid signature' }, 401);
  let event = {};
  try {
    event = JSON.parse(req.body || '{}');
  } catch {
    event = {};
  }
  log(`Razorpay webhook ${event.event || 'unknown'}`);
  return res.json({ ok: true, event: event.event || null });
};
