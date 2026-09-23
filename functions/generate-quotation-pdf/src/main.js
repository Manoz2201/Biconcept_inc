import PDFDocument from 'pdfkit';

/**
 * Builds a quotation PDF from JSON in the request body.
 * Preferred payload: { quotation: { quotationNumber, title, items, subtotal, taxRate, taxAmount, total, validUntil } }
 * quotationId-only calls need a quotations table (not on this Cloud plan) — the Flutter app falls back locally.
 */
export default async ({ req, res, error }) => {
  try {
    const body = JSON.parse(req.body || '{}');
    const q = body.quotation;
    if (!q) {
      return res.json({ error: 'quotation required' }, 400);
    }

    const chunks = [];
    const doc = new PDFDocument({ margin: 48 });
    doc.on('data', (chunk) => chunks.push(chunk));
    const done = new Promise((resolve) => doc.on('end', resolve));

    doc.fontSize(20).text('BiConcept');
    doc.moveDown(0.3);
    doc.fontSize(12).text(`Quotation ${q.quotationNumber || ''}`);
    if (q.title) doc.text(q.title);
    if (q.validUntil) doc.text(`Valid until ${q.validUntil}`);
    doc.moveDown();

    for (const item of q.items || []) {
      const total = item.total ?? (Number(item.quantity || 0) * Number(item.unitPrice || 0));
      doc.text(`${item.description || ''}  ${item.quantity || 0} x ${item.unitPrice || 0} = ${total}`);
    }

    doc.moveDown();
    doc.text(`Subtotal  ${q.subtotal ?? 0}`);
    doc.text(`GST ${q.taxRate ?? 18}%  ${q.taxAmount ?? 0}`);
    doc.fontSize(14).text(`Total  ${q.total ?? 0}`);
    doc.end();
    await done;

    const pdf = Buffer.concat(chunks);
    return res.send(pdf, 200, { 'content-type': 'application/pdf' });
  } catch (e) {
    error?.(e?.message || String(e));
    return res.json({ error: 'pdf_failed', details: e?.message || String(e) }, 500);
  }
};
