// Rwandan mobile-money numbers: 07X XXX XXXX, where 078/079 are MTN and 072/073 are Airtel.
const PROVIDERS = { 8: 'MTN', 9: 'MTN', 2: 'Airtel', 3: 'Airtel' };

// Accepts 0781234567, 250781234567 or +250 781 234 567 and returns the
// number in international format (250781234567) with its provider, or null.
function parseRwandanPhone(input) {
  if (typeof input !== 'string') return null;
  const digits = input.replace(/[\s-]/g, '').replace(/^\+/, '');
  const match = digits.match(/^(?:250|0)(7([2389])\d{7})$/);
  if (!match) return null;
  return { phone: `250${match[1]}`, provider: PROVIDERS[match[2]] };
}

module.exports = { parseRwandanPhone };
