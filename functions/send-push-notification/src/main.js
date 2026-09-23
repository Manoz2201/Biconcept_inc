export default async ({ req, res }) => {
  const { userId, title } = JSON.parse(req.body || '{}');
  return res.json({
    ok: true,
    userId,
    title,
    message: 'FCM server key stays in Function env. Flutter shows a local notification when undeployed.',
  });
};
