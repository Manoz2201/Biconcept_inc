export default async ({ req, res }) => {
  const { section = '194J', vendorType = 'firm', grossAmount = 0, annualGross = 0 } = JSON.parse(req.body || '{}');
  let rate = 0;
  let single;
  let annual;
  if (section === '194C') {
    rate = vendorType === 'individual' || vendorType === 'huf' ? 1 : 2;
    single = 30000;
    annual = 100000;
  } else if (section === '194J') {
    rate = vendorType === 'technical' ? 2 : 10;
    annual = 50000;
  } else if (section === '194I') {
    rate = vendorType === 'plant_machinery' ? 2 : 10;
    annual = 240000;
  } else if (section === '194A') {
    rate = 10;
    annual = 10000;
  } else if (section === '194H') {
    rate = 2;
    annual = 20000;
  } else if (section === '194O') {
    rate = 0.1;
    annual = 500000;
  }
  const crossed = (single && grossAmount >= single) || (annual && Number(annualGross) + Number(grossAmount) >= annual);
  const tdsAmount = crossed ? Math.round(Number(grossAmount) * rate) / 100 : 0;
  return res.json({
    applicable: Boolean(crossed),
    tdsRate: rate,
    tdsAmount,
    netPayable: Math.round((Number(grossAmount) - tdsAmount) * 100) / 100,
    thresholdCrossed: Boolean(crossed),
  });
};
