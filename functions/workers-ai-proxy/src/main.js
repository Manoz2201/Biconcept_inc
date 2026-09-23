/**
 * Browser clients cannot call api.cloudflare.com (CORS). Credentials come
 * from function env (GitHub secrets) first; Settings values are fallback.
 */
export default async ({ req, res, error }) => {
  let body = {};
  try {
    body = JSON.parse(req.body || '{}');
  } catch {
    return res.json({ error: 'invalid_json' }, 400);
  }

  const accountId = String(
    process.env.CLOUDFLARE_ACCOUNT_ID || body.accountId || '',
  ).trim();
  const apiToken = String(process.env.CLOUDFLARE_API_TOKEN || body.apiToken || '')
    .replace(/^bearer\s+/i, '')
    .trim();
  const model = String(body.model || '').trim();
  const payload = body.payload;

  if (body.action === 'verify') {
    const verifyToken = String(body.apiToken || process.env.CLOUDFLARE_API_TOKEN || '')
      .replace(/^bearer\s+/i, '')
      .trim();
    if (!verifyToken) return res.json({ error: 'api_token_required' }, 400);
    try {
      const cf = await fetch('https://api.cloudflare.com/client/v4/user/tokens/verify', {
        headers: { Authorization: `Bearer ${verifyToken}`, Accept: 'application/json' },
      });
      const text = await cf.text();
      let parsed;
      try {
        parsed = JSON.parse(text);
      } catch {
        parsed = { raw: text };
      }
      return res.json({ status: cf.status, body: parsed });
    } catch (e) {
      error?.(e?.message || String(e));
      return res.json({ error: 'cloudflare_unreachable', details: e?.message || String(e) }, 502);
    }
  }

  if (!/^[a-f0-9]{32}$/i.test(accountId)) {
    return res.json({ error: 'invalid_account_id' }, 400);
  }
  if (!apiToken) {
    return res.json({ error: 'api_token_required' }, 400);
  }
  if (!model.startsWith('@cf/') || model.includes('..') || model.includes('\\')) {
    return res.json({ error: 'invalid_model' }, 400);
  }
  if (payload == null || typeof payload !== 'object') {
    return res.json({ error: 'payload_required' }, 400);
  }

  const url = `https://api.cloudflare.com/client/v4/accounts/${accountId}/ai/run/${model}`;
  try {
    const cf = await fetch(url, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiToken}`,
        'Content-Type': 'application/json',
        Accept: 'application/json',
      },
      body: JSON.stringify(payload),
    });
    const text = await cf.text();
    let parsed;
    try {
      parsed = JSON.parse(text);
    } catch {
      parsed = { raw: text };
    }
    return res.json({ status: cf.status, body: parsed });
  } catch (e) {
    error?.(e?.message || String(e));
    return res.json({ error: 'cloudflare_unreachable', details: e?.message || String(e) }, 502);
  }
};
