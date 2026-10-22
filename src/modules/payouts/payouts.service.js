const { collection } = require('../../common/store');
const { badRequest, conflict } = require('../../common/errors');
const { getGroup } = require('../groups/groups.service');
const { listMembers } = require('../members/members.service');
const { totalContributed } = require('../contributions/contributions.service');

const MIN_MEMBERS = 2;
const payouts = () => collection('payouts');

function listPayouts(groupId) {
  getGroup(groupId);
  return payouts().findAll((p) => p.groupId === groupId);
}

function totalPaidOut(groupId) {
  return listPayouts(groupId).reduce((sum, p) => sum + p.amount, 0);
}

// Members are paid in join order. Once everyone has had a turn, a new round starts.
function getNextPayout(groupId) {
  const group = getGroup(groupId);
  const members = listMembers(groupId);
  if (members.length < MIN_MEMBERS) return null;

  const paidCount = listPayouts(groupId).length;
  const member = members[paidCount % members.length];
  const amount = group.contributionAmount * members.length;
  const potBalance = totalContributed(groupId) - totalPaidOut(groupId);

  return {
    round: Math.floor(paidCount / members.length) + 1,
    member: { id: member.id, fullName: member.fullName, phone: member.phone },
    amount,
    potBalance,
    ready: potBalance >= amount,
  };
}

function makePayout(groupId) {
  const next = getNextPayout(groupId);
  if (!next) throw badRequest(`A group needs at least ${MIN_MEMBERS} members before payouts`);
  if (!next.ready) {
    throw conflict(
      `Not enough in the pot: ${next.amount} needed, ${next.potBalance} available`,
    );
  }

  return payouts().insert({
    groupId,
    memberId: next.member.id,
    amount: next.amount,
    round: next.round,
  });
}

module.exports = { listPayouts, totalPaidOut, getNextPayout, makePayout };
