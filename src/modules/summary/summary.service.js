const config = require('../../config');
const { getGroup } = require('../groups/groups.service');
const { listMembers } = require('../members/members.service');
const { totalContributed } = require('../contributions/contributions.service');
const { listPayouts, totalPaidOut, getNextPayout } = require('../payouts/payouts.service');

// One read-only view of the group for meetings. It only calls other modules'
// services, so it could become a separate reporting service later.
function getSummary(groupId) {
  const group = getGroup(groupId);
  const members = listMembers(groupId);
  const contributed = totalContributed(groupId);
  const paidOut = totalPaidOut(groupId);
  const next = getNextPayout(groupId);

  return {
    group: { id: group.id, name: group.name, frequency: group.frequency, contributionAmount: group.contributionAmount },
    currency: config.currency,
    memberCount: members.length,
    totalContributed: contributed,
    totalPaidOut: paidOut,
    potBalance: contributed - paidOut,
    payoutsMade: listPayouts(groupId).length,
    nextPayout: next,
  };
}

module.exports = { getSummary };