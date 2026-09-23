export default async ({ req, res }) => {
  const { backupJobId } = JSON.parse(req.body || '{}');
  return res.json({
    ok: true,
    backupJobId,
    message: 'AES key stays in Function env. Flutter writes a gzip snapshot to portfolio_images when undeployed.',
  });
};
