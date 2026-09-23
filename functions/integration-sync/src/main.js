export default async ({ req, res }) => {
  const { integrationId, syncType = 'incremental' } = JSON.parse(req.body || '{}');
  return res.json({
    ok: true,
    integrationId,
    syncType,
    recordsProcessed: 0,
    recordsSucceeded: 0,
    recordsFailed: 0,
    message: 'OAuth and Tally credentials stay in Function env. Never write secrets to Appwrite rows.',
  });
};
