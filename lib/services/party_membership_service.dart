// ─────────────────────────────────────────────
//  Polyticks – Party Membership Service
//  Join requests (#7/#7.b), hierarchy roles (#6),
//  unified accounts (#8). Simulation-layer logic.
// ─────────────────────────────────────────────
import '../models/models.dart';
import '../data/mock_data.dart';

class MembershipResult {
  final bool ok;
  final String? reason;
  const MembershipResult(this.ok, [this.reason]);
}

class PartyMembershipService {
  static List<AppUser> get _users =>
      mockAccounts.map((a) => a['user'] as AppUser).toList();

  /// Janta member requests to join a party. Enforces single-party
  /// membership (7.b) and no duplicate pending request.
  static MembershipResult requestToJoin(AppUser user, String partyId) {
    if (user.partyId != null) {
      final current = partyById(user.partyId!);
      return MembershipResult(
          false,
          'You are already a member of ${current?.name ?? 'another party'} '
          '(${current?.shortName ?? '?'}) — open your party page to leave it '
          'before applying elsewhere.');
    }
    if (mockJoinRequests.any((r) => r.userId == user.id && r.status == 'pending')) {
      return const MembershipResult(false, 'You already have a pending membership request.');
    }
    if (mockJoinRequests.any((r) =>
        r.userId == user.id && r.partyId == partyId && r.status == 'approved')) {
      return const MembershipResult(false, 'Your membership to this party is already active.');
    }

    mockJoinRequests.insert(
      0,
      JoinRequest(
        id: 'jr_${DateTime.now().millisecondsSinceEpoch}',
        userId: user.id,
        username: user.displayName,
        partyId: partyId,
        createdAt: DateTime.now(),
      ),
    );
    return const MembershipResult(true);
  }

  /// Party approves → the SAME account is promoted to partyMember (#8).
  static void approveJoin(JoinRequest req) {
    if (req.status != 'pending') return;
    req.status = 'approved';
    final user = userById(req.userId);
    if (user != null) {
      user.role = UserRole.partyMember;
      user.partyId = req.partyId; // single-party invariant
      user.partyRole = null;
    }
    final party = partyById(req.partyId);
    // memberCount is final in the model – tracked implicitly via users.
    assert(party != null);
  }

  static void rejectJoin(JoinRequest req) {
    if (req.status != 'pending') return;
    req.status = 'rejected';
  }

  /// Can `assigner` grant/revoke roles in this party?
  /// Official: all tiers. Top-tier members: strictly lower tiers only.
  static bool canManageRoles(AppUser? assigner, String partyId) {
    if (assigner == null) return false;
    if (assigner.role == UserRole.party && assigner.partyId == partyId) {
      return true;
    }
    return assigner.role == UserRole.partyMember &&
        assigner.partyId == partyId &&
        assigner.partyRole?.isTopTier == true;
  }

  static MembershipResult assignRole(
      AppUser target, PartyRole role, AppUser assigner) {
    if (target.role != UserRole.partyMember || target.partyId == null) {
      return const MembershipResult(false, 'Target is not a party member.');
    }
    if (!canManageRoles(assigner, target.partyId!)) {
      return const MembershipResult(false,
          'You do not have authority to assign roles in this party.');
    }
    final isOfficial = assigner.role == UserRole.party;
    if (!isOfficial && role.isTopTier) {
      return const MembershipResult(false,
          'Top-tier roles can only be assigned by the Party Official account.');
    }
    if (!isOfficial &&
        assigner.partyRole != null &&
        assigner.partyRole!.tier >= role.tier) {
      return const MembershipResult(false,
          'You can only assign roles strictly below your own tier.');
    }
    // Unique role holder per party
    for (final u in _users) {
      if (u.id != target.id &&
          u.role == UserRole.partyMember &&
          u.partyId == target.partyId &&
          u.partyRole == role) {
        return MembershipResult(
            false, '${role.label} is already held by ${u.displayName}. Roles are unique.');
      }
    }
    target.partyRole = role;
    return const MembershipResult(true);
  }

  static MembershipResult revokeRole(AppUser target, AppUser revoker) {
    if (target.partyId == null) {
      return const MembershipResult(false, 'Target is not a party member.');
    }
    if (!canManageRoles(revoker, target.partyId!)) {
      return const MembershipResult(false, 'No authority to revoke roles.');
    }
    target.partyRole = null;
    return const MembershipResult(true);
  }

  /// Removal / leaving reverts to plain Janta and unblocks join requests (7.b).
  static MembershipResult removeMember(AppUser target, AppUser remover) {
    if (target.partyId == null) {
      return const MembershipResult(false, 'Target is not a party member.');
    }
    if (!canManageRoles(remover, target.partyId!)) {
      return const MembershipResult(false, 'No authority to remove members.');
    }
    _revertToJanta(target);
    return const MembershipResult(true);
  }

  static void leaveParty(AppUser user) {
    if (user.partyId == null) return;
    _revertToJanta(user);
  }

  static void _revertToJanta(AppUser user) {
    user.role = UserRole.janta;
    user.partyId = null;
    user.partyRole = null;
  }
}
