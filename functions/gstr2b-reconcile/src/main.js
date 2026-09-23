export default async ({ req, res, log }) => {
  const { importId } = JSON.parse(req.body || '{}');
  log(`Reconcile ${importId || 'unknown'} — matching runs in the Flutter app against packed vendor and compliance workspaces.`);
  return res.json({
    success: true,
    note: 'Client-side GSTR-2B matching is the source of truth. This Function is a hook for server-side re-runs.',
    importId,
  });
};
