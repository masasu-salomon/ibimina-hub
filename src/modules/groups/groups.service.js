const { collection } = require('../../common/store');
const { badRequest, notFound } = require('../../common/errors');
const { requiredString, positiveAmount, oneOf, collectErrors } = require('../../common/validate');

const FREQUENCIES = ['weekly', 'monthly'];
const groups = () => collection('groups');

function createGroup({ name, contributionAmount, frequency, location } = {}) {
  const errors = collectErrors(
    requiredString(name, 'name', { min: 3 }),
    positiveAmount(contributionAmount, 'contributionAmount'),
    oneOf(frequency, 'frequency', FREQUENCIES),
    location === undefined ? null : requiredString(location, 'location'),
  );
  if (errors.length) throw badRequest('Invalid group', errors);

  return groups().insert({
    name: name.trim(),
    contributionAmount,
    frequency,
    location: location ? location.trim() : null,
  });
}

function listGroups() {
  return groups().findAll();
}

function getGroup(id) {
  const group = groups().findById(id);
  if (!group) throw notFound(`Group ${id} not found`);
  return group;
}

module.exports = { createGroup, listGroups, getGroup, FREQUENCIES };
