export default async ({ req, res }) => {
  const { tdsDeductionId } = JSON.parse(req.body || '{}');
  return res.json({
    success: false,
    error: 'Form 16A is generated in the Flutter app with the pdf package. Deploy this Function only if you need a server-side buffer.',
    tdsDeductionId,
  });
};
