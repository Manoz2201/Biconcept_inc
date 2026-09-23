export default async ({ req, res }) => {
  const { backupHistoryId } = JSON.parse(req.body || '{}');
  return res.json({ ok: true, backupHistoryId, dryRun: false });
};
