// Small validation helpers. Each returns an error message, or null when valid.

function requiredString(value, field, { min = 1, max = 100 } = {}) {
  if (typeof value !== 'string' || value.trim().length < min) {
    return `${field} is required`;
  }
  if (value.trim().length > max) return `${field} must be at most ${max} characters`;
  return null;
}

function positiveAmount(value, field) {
  if (!Number.isInteger(value) || value <= 0) {
    return `${field} must be a positive whole number`;
  }
  return null;
}

function oneOf(value, field, allowed) {
  if (!allowed.includes(value)) return `${field} must be one of: ${allowed.join(', ')}`;
  return null;
}

// Collects the non-null messages so the client gets every problem at once.
function collectErrors(...messages) {
  return messages.filter(Boolean);
}

module.exports = { requiredString, positiveAmount, oneOf, collectErrors };
