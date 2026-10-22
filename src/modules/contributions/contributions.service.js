const { collection } = require('../../common/store');
const { badRequest } = require('../../common/errors');
const { positiveAmount } = require('../../common/validate');
const { getGroup } = require('../groups/groups.service');
const { getMember, listMembers } = require('../members/members.service');

const contributions = () => collection('contributions');

// Amount defaults to the group's fixed contribution, which is the usual case.
function recordContribution(groupId, { memberId, amount } = {}) {
  const group = getGroup(groupId);
  if (typeof memberId !== 'string') throw badRequest('Invalid contribution', ['memberId is required']);
  const member = getMember(groupId, memberId);

  const value = amount === undefined ? group.contributionAmount : amount;
  const error = positiveAmount(value, 'amount');
  if (error) throw badRequest('Invalid contribution', [error]);

  return contributions().insert({ groupId, memberId: member.id, amount: value });
}

function listContributions(groupId, { memberId } = {}) {
  getGroup(groupId);
  return contributions().findAll(
    (c) => c.groupId === groupId && (!memberId || c.memberId === memberId),
  );
}

function totalContributed(groupId) {
  return listContributions(groupId).reduce((sum, c) => sum + c.amount, 0);
}

function getBalance(groupId) {
  const all = listContributions(groupId);
  const members = listMembers(groupId).map((m) => {
    const own = all.filter((c) => c.memberId === m.id);
    return {
      memberId: m.id,
      fullName: m.fullName,
      contributions: own.length,
      total: own.reduce((sum, c) => sum + c.amount, 0),
    };
  });

  return {
    groupId,
    totalContributed: all.reduce((sum, c) => sum + c.amount, 0),
    members,
  };
}

module.exports = { recordContribution, listContributions, totalContributed, getBalance };
