export default async ({ req, res }) => {
  const { scheduleId } = JSON.parse(req.body || '{}');
  return res.json({
    ok: true,
    scheduleId,
    status: 'recorded',
    message: 'Gateway credentials stay in Function env. Flutter records the payment locally when this is undeployed.',
  });
};
