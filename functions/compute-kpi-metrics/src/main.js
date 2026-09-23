export default async ({ res }) => {
  return res.json({ ok: true, computed: 0, message: 'Flutter computes KPIs from invoices and projects when undeployed.' });
};
