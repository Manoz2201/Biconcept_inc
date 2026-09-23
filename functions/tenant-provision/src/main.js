export default async ({ req, res }) => {
  const body = JSON.parse(req.body || '{}');
  if (req.method === 'GET' && body.challenge == null && req.query) {
    const token = req.query['hub.verify_token'];
    const challenge = req.query['hub.challenge'];
    if (token && token === process.env.WHATSAPP_VERIFY_TOKEN) {
      return res.send(challenge, 200);
    }
  }
  return res.json({
    ok: true,
    function: 'tenant-provision',
    echo: body,
    message: 'Secrets stay in Function env (OPENAI_API_KEY, WHATSAPP_ACCESS_TOKEN). Flutter falls back to local heuristics when undeployed.',
  });
};
