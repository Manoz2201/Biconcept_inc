export default async ({ req, res, log }) => {
  const source = process.env.FX_API_KEY ? 'openexchangerates' : 'manual';
  log(`Exchange rates would refresh from ${source}. Store API keys in Function env only.`);
  return res.json({ ok: true, source, updated: 0, message: 'Client applies rates when this Function is undeployed' });
};
