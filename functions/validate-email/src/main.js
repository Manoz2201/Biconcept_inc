import { verifyEmail } from '@emailcheck/email-validator-js';

/**
 * Maps @emailcheck/email-validator-js onto the contract the Flutter app expects.
 * The package API is object-based (emailAddress, verifyMx, …); the app reads
 * isValid / isDisposable / mxFound / suggestion / reason.
 */
export default async ({ req, res, error }) => {
  try {
    const { email } = JSON.parse(req.body || '{}');
    if (!email) return res.json({ error: 'email required' }, 400);

    const r = await verifyEmail({
      emailAddress: email,
      verifyMx: true,
      verifySmtp: false,
      checkDisposable: true,
      checkFree: true,
      suggestDomain: true,
    });

    const mxFound = r.validMx === true;
    const isDisposable = r.isDisposable === true;
    const isValid = r.validFormat === true && !isDisposable && r.validMx !== false;

    return res.json({
      isValid,
      isDisposable,
      isFreeProvider: r.isFree === true,
      mxFound,
      suggestion: r.domainSuggestion?.suggested || null,
      reason: r.metadata?.error || null,
    });
  } catch (e) {
    error?.(e?.message || String(e));
    return res.json(
      { error: 'validation_failed', details: e?.message || String(e) },
      500,
    );
  }
};
