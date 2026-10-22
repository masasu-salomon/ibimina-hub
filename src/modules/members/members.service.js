const { collection } = require('../../common/store');
const { badRequest, notFound, conflict } = require('../../common/errors');
const { requiredString, collectErrors } = require('../../common/validate');
const { getGroup } = require('../groups/groups.service');
const { parseRwandanPhone } = require('./phone');

const members = () => collection('members');

function addMember(groupId, { fullName, phone } = {}) {
  getGroup(groupId);

  const parsed = parseRwandanPhone(phone);
  const errors = collectErrors(
    requiredString(fullName, 'fullName', { min: 3 }),
    parsed ? null : 'phone must be a valid Rwandan MTN or Airtel number (e.g. 0781234567)',
  );
  if (errors.length) throw badRequest('Invalid member', errors);

  const existing = listMembers(groupId);
  if (existing.some((m) => m.phone === parsed.phone)) {
    throw conflict(`A member with phone ${parsed.phone} is already in this group`);
  }

  // Join order decides the payout rotation.
  return members().insert({
    groupId,
    fullName: fullName.trim(),
    phone: parsed.phone,
    provider: parsed.provider,
    position: existing.length + 1,
  });
}

function listMembers(groupId) {
  getGroup(groupId);
  return members()
    .findAll((m) => m.groupId === groupId)
    .sort((a, b) => a.position - b.position);
}

function getMember(groupId, memberId) {
  const member = members().findById(memberId);
  if (!member || member.groupId !== groupId) {
    throw notFound(`Member ${memberId} not found in group ${groupId}`);
  }
  return member;
}

module.exports = { addMember, listMembers, getMember };
