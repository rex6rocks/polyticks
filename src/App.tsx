import React, { useState } from 'react';
import { AppUser, Party, Post, Comment, Poll, VerificationRequest, InteractionType, PostType, ChannelType, NotificationItem, JoinRequest, PartyRole, ReportEntry } from './types';
import { storageService, PurgeRecord } from './services/storageService';
import { Navbar } from './components/Navbar';
import { FeedScreen } from './screens/FeedScreen';
import { ExploreScreen } from './screens/ExploreScreen';
import { PartyProfileScreen } from './screens/PartyProfileScreen';
import { AdminConsoleScreen } from './screens/AdminConsoleScreen';
import { IdVerificationScreen } from './screens/IdVerificationScreen';
import { ProfileScreen } from './screens/ProfileScreen';
import { NotificationsScreen } from './screens/NotificationsScreen';
import { LoginScreen } from './screens/LoginScreen';
import { OtpScreen } from './screens/OtpScreen';
import { SignupScreen } from './screens/SignupScreen';
import { CreatePostModal } from './components/CreatePostModal';
import { CreatePollModal } from './components/CreatePollModal';
import { PostDetailScreen } from './components/PostDetailScreen';

export const App: React.FC = () => {
  // Application Data States
  const [currentUser, setCurrentUser] = useState<AppUser>(() => storageService.getCurrentUser());
  const [allUsers, setAllUsers] = useState<AppUser[]>(() => storageService.getUsers());
  const [parties, setParties] = useState<Party[]>(() => storageService.getParties());
  const [posts, setPosts] = useState<Post[]>(() => storageService.getPosts());
  const [comments, setComments] = useState<Comment[]>(() => storageService.getComments());
  const [polls, setPolls] = useState<Poll[]>(() => storageService.getPolls());
  const [verifications, setVerifications] = useState<VerificationRequest[]>(() => storageService.getVerifications());
  const [purgeLogs, setPurgeLogs] = useState<PurgeRecord[]>(() => storageService.getPurgeLogs());
  const [notifications, setNotifications] = useState<NotificationItem[]>(() => storageService.getNotifications());
  const [joinRequests, setJoinRequests] = useState<JoinRequest[]>(() => storageService.getJoinRequests());
  const [activePostId, setActivePostId] = useState<string | null>(null);
  const [postReturnTab, setPostReturnTab] = useState<string>('feed');
  const [reports, setReports] = useState<ReportEntry[]>(() => storageService.getReports());

  // Navigation State: 'feed' | 'explore' | 'party' | 'verification' | 'profile' | 'notifications' | 'login' | 'otp' | 'signup' | 'admin' (admin only)
  const [currentTab, setCurrentTab] = useState<string>('feed');
  const [activePartyId, setActivePartyId] = useState<string>('p1');
  const [pendingPhone, setPendingPhone] = useState<string>('+91 98765 43210');
  const [isCreatePostOpen, setIsCreatePostOpen] = useState<boolean>(false);
  const [showCreatePoll, setShowCreatePoll] = useState<boolean>(false);
  const [toastMessage, setToastMessage] = useState<string | null>(null);

  const showToast = (msg: string) => {
    setToastMessage(msg);
    setTimeout(() => setToastMessage(null), 3500);
  };

  // Sync users when changed
  const handleSwitchUser = (userId: string) => {
    const user = storageService.setCurrentUser(userId);
    setCurrentUser(user);
    setAllUsers(storageService.getUsers());
    showToast(`Switched account to: ${user.displayName} (${user.role})`);
  };

  const handleUpdateUser = (updated: AppUser) => {
    storageService.updateUser(updated);
    setCurrentUser(updated);
    setAllUsers(storageService.getUsers());
    showToast('Profile updated successfully.');
  };

  // Post Actions
  const handleReact = (postId: string, reaction: InteractionType) => {
    const updated = storageService.reactToPost(postId, reaction);
    if (updated) {
      setPosts(storageService.getPosts());
    }
  };

  const handleAddComment = (postId: string, content: string, parentId?: string) => {
    storageService.addComment(postId, currentUser, content, parentId);
    setComments(storageService.getComments());
    setPosts(storageService.getPosts());
    showToast(parentId ? 'Reply published.' : 'Comment published to civic thread.');
  };

  const handleReactToComment = (commentId: string, reaction: InteractionType) => {
    storageService.reactToComment(commentId, reaction);
    setComments(storageService.getComments());
  };

  const handleReportContent = (targetType: 'post' | 'comment', targetId: string, reason: string) => {
    const result = storageService.reportContent(targetType, targetId, reason, currentUser);
    if (result) {
      setReports(storageService.getReports());
      showToast('Report submitted for moderation review.');
    } else {
      showToast('You have already reported this content.');
    }
  };

  const handleResolveReport = (reportId: string, takeDown: boolean) => {
    storageService.resolveReport(reportId, takeDown);
    setReports(storageService.getReports());
    setPosts(storageService.getPosts());
    setComments(storageService.getComments());
    showToast(takeDown ? 'Content taken down.' : 'Report dismissed and content restored.');
  };

  const openPost = (postId: string) => {
    setActivePostId(postId);
    setPostReturnTab(currentTab);
    setCurrentTab('postDetail');
    window.scrollTo({ top: 0 });
  };

  const handleEditPost = (postId: string, newContent: string) => {
    const updated = storageService.editPost(postId, newContent);
    if (updated) {
      setPosts(storageService.getPosts());
      showToast('Post updated and appended to public audit trail.');
    }
  };

  const handleCreatePost = (data: {
    partyId: string;
    content: string;
    imageEmoji?: string;
    type: PostType;
    channelType: ChannelType;
    communityId?: string;
    authorId?: string;
    authorName?: string;
  }) => {
    storageService.createPost(data);
    setPosts(storageService.getPosts());
    showToast('Your civic post is live on the network!');
  };

  // Poll Voting
  const handleVotePoll = (pollId: string, optionId: string) => {
    const updated = storageService.votePoll(pollId, optionId);
    if (updated) {
      setPolls(storageService.getPolls());
      showToast('Your verified member ballot vote has been recorded.');
    }
  };

  // Poll Creation (party official)
  const handleCreatePoll = (newPoll: Poll) => {
    const created = storageService.createPoll(newPoll);
    if (created) {
      setPolls(storageService.getPolls());
      showToast('Poll posted for verified members to vote.');
    } else {
      showToast('Could not post poll. Please try again.');
    }
  };

  // Party Actions
  const handleToggleFollow = (partyId: string) => {
    const following = storageService.toggleFollow(currentUser.id, partyId);
    setParties(storageService.getParties());
    const party = parties.find((p) => p.id === partyId);
    showToast(
      following
        ? `Now following ${party?.name || 'Party'}`
        : `Unfollowed ${party?.name || 'Party'}`
    );
  };

  const handlePartyClick = (partyId: string) => {
    setActivePartyId(partyId);
    setCurrentTab('party');
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  // Membership Join Request Flow (#7 / #7.b)
  const handleRequestToJoin = (partyId: string): { ok: boolean; reason?: string } => {
    const result = storageService.requestToJoinParty(currentUser.id, partyId);
    if (result.ok) {
      setJoinRequests(storageService.getJoinRequests());
      setNotifications(storageService.getNotifications());
      showToast('Membership request sent to the party for approval.');
    } else if (result.reason) {
      showToast(result.reason);
    }
    return result;
  };

  const refreshMembershipState = () => {
    setJoinRequests(storageService.getJoinRequests());
    setAllUsers(storageService.getUsers());
    setParties(storageService.getParties());
    setNotifications(storageService.getNotifications());
    setCurrentUser(storageService.getCurrentUser());
  };

  const handleApproveJoin = (requestId: string) => {
    storageService.approveJoinRequest(requestId);
    refreshMembershipState();
    showToast('Membership approved. The account is now a Party Member.');
  };

  const handleRejectJoin = (requestId: string) => {
    storageService.rejectJoinRequest(requestId);
    refreshMembershipState();
    showToast('Membership request rejected.');
  };

  // Party Hierarchy Roles (#6)
  const handleAssignRole = (userId: string, role: PartyRole): { ok: boolean; reason?: string } => {
    const result = storageService.assignPartyRole(userId, role, currentUser);
    if (result.ok) {
      setAllUsers(storageService.getUsers());
      setCurrentUser(storageService.getCurrentUser());
      showToast('Party role assigned.');
    } else if (result.reason) {
      showToast(result.reason);
    }
    return result;
  };

  const handleRevokeRole = (userId: string) => {
    const result = storageService.revokePartyRole(userId, currentUser);
    if (result.ok) {
      setAllUsers(storageService.getUsers());
      setCurrentUser(storageService.getCurrentUser());
      showToast('Party role revoked.');
    } else if (result.reason) {
      showToast(result.reason);
    }
  };

  const handleRemoveMember = (userId: string) => {
    const result = storageService.removeMemberFromParty(userId, currentUser);
    if (result.ok) {
      refreshMembershipState();
      setPosts(storageService.getPosts());
      showToast('Member removed. Account reverted to Janta.');
    } else if (result.reason) {
      showToast(result.reason);
    }
  };

  const handleLeaveParty = () => {
    storageService.leaveParty(currentUser.id);
    refreshMembershipState();
    showToast('You left the party and are now a Janta member again.');
  };

  // Verification & Admin Actions
  const handleInstantDigiLockerVerify = () => {
    const updated = {
      ...currentUser,
      isVerified: true,
      displayName: currentUser.displayName.includes('(Verified)')
        ? currentUser.displayName
        : `${currentUser.displayName} (Verified)`,
    };
    storageService.updateUser(updated);
    setCurrentUser(updated);
    setAllUsers(storageService.getUsers());
    showToast('Identity verified via DigiLocker e-ID Gateway! Instant badge applied.');
  };

  // Re-KYC, Unlink Account, and Login Later handlers
  const handleReKyc = () => {
    const updated = {
      ...currentUser,
      isVerified: false,
    };
    storageService.updateUser(updated);
    setCurrentUser(updated);
    setAllUsers(storageService.getUsers());
    setCurrentTab('verification');
    showToast('Re-KYC initiated. Please verify your civic credentials.');
  };

  const handleUnlinkAccount = () => {
    const updated: AppUser = {
      ...currentUser,
      partyId: undefined,
      partyRole: undefined,
      role: 'janta',
      isVerified: false,
      displayName: currentUser.displayName.replace(' (Verified)', ''),
    };
    storageService.updateUser(updated);
    setCurrentUser(updated);
    setAllUsers(storageService.getUsers());
    showToast('Account credentials & verification unlinked. Reverted to unverified Janta citizen.');
  };

  const handleLoginLater = () => {
    const guest = allUsers.find((u) => u.role === 'janta') || allUsers[0];
    setCurrentUser(guest);
    setCurrentTab('feed');
    showToast(`Browsing as Guest (${guest.displayName})`);
  };

  const handleSubmitVerification = (data: {
    documentType: string;
    imageUrl: string;
    fileSizeKb: number;
  }) => {
    storageService.submitVerification(
      currentUser.id,
      currentUser.displayName,
      currentUser.phone || '+91 98765 00000',
      currentUser.role,
      data.documentType,
      data.imageUrl,
      data.fileSizeKb
    );
    setVerifications(storageService.getVerifications());
    showToast('Government ID submitted. In zero-retention review.');
  };

  const handleApproveVerification = (verId: string) => {
    storageService.approveVerification(verId);
    setVerifications(storageService.getVerifications());
    setPurgeLogs(storageService.getPurgeLogs());
    setAllUsers(storageService.getUsers());
    setCurrentUser(storageService.getCurrentUser());
    showToast('Identity approved! Document file permanently purged from storage.');
  };

  const handleRejectVerification = (verId: string) => {
    storageService.rejectVerification(verId);
    setVerifications(storageService.getVerifications());
    setPurgeLogs(storageService.getPurgeLogs());
    showToast('Identity rejected. Document file permanently purged from storage.');
  };

  // Fact-Check and Moderation Handlers
  const handleSubmitFactCheck = (postId: string, contextNote: string, sources: string[]) => {
    storageService.submitFactCheckNote(postId, contextNote, sources);
    setPosts(storageService.getPosts());
    showToast('Community context note submitted and attached to post.');
  };

  const handleModeratePost = (postId: string, approveRestore: boolean) => {
    storageService.resolveModerationPost(postId, approveRestore);
    setPosts(storageService.getPosts());
    showToast(
      approveRestore
        ? 'Post verified, approved, and restored to public feed.'
        : 'Post permanently deleted from platform.'
    );
  };

  // Notifications
  const handleMarkAllNotificationsRead = () => {
    storageService.markAllNotificationsRead();
    setNotifications(storageService.getNotifications());
    showToast('All notifications marked as read.');
  };

  // Auth Navigation Handlers
  const handleRequestOtp = (phone: string) => {
    setPendingPhone(phone);
    setCurrentTab('otp');
  };

  const handleVerifyOtp = (_otp: string) => {
    // Find matching user or fallback to first
    const clean = pendingPhone.replace(/\D/g, '');
    const found = allUsers.find((u) => u.phone?.includes(clean) || u.email.includes(clean));
    if (found) {
      handleSwitchUser(found.id);
    } else {
      handleSwitchUser(allUsers[0].id);
    }
    setCurrentTab('feed');
    showToast('Successfully authenticated via secure OTP!');
  };

  const handleRegister = (newUser: AppUser) => {
    storageService.createUser(newUser);
    setCurrentUser(newUser);
    setAllUsers(storageService.getUsers());
    setCurrentTab('verification');
    showToast(`Account created for ${newUser.displayName}! Next: Verify Government ID.`);
  };

  const activeParty = parties.find((p) => p.id === activePartyId) || parties[0];
  const activePost = posts.find((p) => p.id === activePostId);

  return (
    <div className="min-h-screen bg-[#0B1220] text-white flex flex-col font-sans">
      {/* Toast Notification */}
      {toastMessage && (
        <div className="fixed top-20 right-4 z-50 bg-[#121B2E] border border-[#FF7A2F]/40 text-white text-xs font-semibold px-4 py-3 rounded-2xl shadow-2xl animate-in fade-in slide-in-from-top-4 duration-200 flex items-center gap-2">
          <span className="text-[#FF7A2F]">✓</span>
          <span>{toastMessage}</span>
        </div>
      )}

      {/* Top Navigation Bar */}
      {currentTab !== 'login' && currentTab !== 'otp' && currentTab !== 'signup' && (
        <Navbar
          currentUser={currentUser}
          allUsers={allUsers}
          parties={parties}
          onSwitchUser={handleSwitchUser}
          currentTab={currentTab}
          onNavigate={(tab, param) => {
            if (tab === 'party' && param) {
              setActivePartyId(param);
            }
            setCurrentTab(tab);
            window.scrollTo({ top: 0, behavior: 'smooth' });
          }}
          onOpenCreatePost={() => setIsCreatePostOpen(true)}
          notifications={notifications}
          onOpenVerification={() => setCurrentTab('verification')}
        />
      )}

      {/* Main Content Area */}
      <div className="flex-1">
        {currentTab === 'feed' && (
          <FeedScreen
            currentUser={currentUser}
            parties={parties}
            posts={posts}
            comments={comments}
            polls={polls}
            onReact={handleReact}
            onAddComment={handleAddComment}
            onEditPost={handleEditPost}
            onVotePoll={handleVotePoll}
            onPartyClick={handlePartyClick}
            onOpenPost={openPost}
            onOpenCreatePost={() => setIsCreatePostOpen(true)}
            onOpenVerification={() => setCurrentTab('verification')}
            onSubmitFactCheck={handleSubmitFactCheck}
          />
        )}

        {/* Post Detail (reading) view */}
        {currentTab === 'postDetail' && activePost && (
          <PostDetailScreen
            post={activePost}
            currentUser={currentUser}
            parties={parties}
            comments={comments}
            onBack={() => setCurrentTab(postReturnTab)}
            onReact={handleReact}
            onAddComment={handleAddComment}
            onReactComment={handleReactToComment}
            onReportPost={(postId, reason) => handleReportContent('post', postId, reason)}
            onReportComment={(commentId, reason) => handleReportContent('comment', commentId, reason)}
          />
        )}

        {currentTab === 'explore' && (
          <ExploreScreen
            parties={parties}
            currentUser={currentUser}
            isFollowingParty={(partyId) => storageService.isFollowing(currentUser.id, partyId)}
            onToggleFollow={handleToggleFollow}
            onPartyClick={handlePartyClick}
          />
        )}

        {currentTab === 'party' && activeParty && (
          <PartyProfileScreen
            party={activeParty}
            currentUser={currentUser}
            allUsers={allUsers}
            joinRequests={joinRequests}
            isFollowing={storageService.isFollowing(currentUser.id, activeParty.id)}
            onToggleFollow={() => handleToggleFollow(activeParty.id)}
            posts={posts}
            comments={comments}
            polls={polls}
            onBack={() => setCurrentTab('feed')}
            onReact={handleReact}
            onAddComment={handleAddComment}
            onEditPost={handleEditPost}
            onVotePoll={handleVotePoll}
            onOpenCreatePost={() => setIsCreatePostOpen(true)}
            onSubmitFactCheck={handleSubmitFactCheck}
            onRequestToJoin={handleRequestToJoin}
            onApproveJoin={handleApproveJoin}
            onRejectJoin={handleRejectJoin}
            onAssignRole={handleAssignRole}
            onRevokeRole={handleRevokeRole}
            onRemoveMember={handleRemoveMember}
            onLeaveParty={handleLeaveParty}
            onToggleMemberFollow={(memberId) => {
              const following = storageService.toggleMemberFollow(memberId, currentUser.id);
              setAllUsers(storageService.getUsers());
              const target = allUsers.find((u) => u.id === memberId);
              showToast(following ? `Now following ${target?.displayName || 'Member'}` : `Unfollowed ${target?.displayName || 'Member'}`);
            }}
            isFollowingMember={(memberId) => storageService.isFollowingMember(memberId, currentUser.id)}
            getMemberFollowerCount={(memberId) => storageService.getMemberFollowers(memberId).length}
            onOpenPost={openPost}
            onCreatePoll={handleCreatePoll}
            onOpenCreatePoll={() => setShowCreatePoll(true)}
          />
        )}

        {currentTab === 'admin' && currentUser.role === 'admin' && (
          <AdminConsoleScreen
            verifications={verifications}
            purgeLogs={purgeLogs}
            posts={posts}
            reports={reports}
            onApprove={handleApproveVerification}
            onReject={handleRejectVerification}
            onModeratePost={handleModeratePost}
            onResolveReport={handleResolveReport}
          />
        )}

        {currentTab === 'verification' && (
          <IdVerificationScreen
            currentUser={currentUser}
            onSubmitVerification={handleSubmitVerification}
            onInstantVerify={handleInstantDigiLockerVerify}
            onBack={() => setCurrentTab('feed')}
            onBrowseFeed={() => setCurrentTab('feed')}
          />
        )}

        {currentTab === 'profile' && (
          <ProfileScreen
            currentUser={currentUser}
            parties={parties}
            allUsers={allUsers}
            onUpdateUser={handleUpdateUser}
            onSwitchUser={handleSwitchUser}
            onOpenVerification={() => setCurrentTab('verification')}
            onReKyc={handleReKyc}
            onUnlinkAccount={handleUnlinkAccount}
            onPartyClick={handlePartyClick}
            onLogout={() => setCurrentTab('login')}
            onLeaveParty={handleLeaveParty}
          />
        )}

        {currentTab === 'notifications' && (
          <NotificationsScreen
            notifications={notifications}
            onMarkAllRead={handleMarkAllNotificationsRead}
            onPartyClick={handlePartyClick}
            onBack={() => setCurrentTab('feed')}
          />
        )}

        {currentTab === 'login' && (
          <LoginScreen
            allUsers={allUsers}
            parties={parties}
            onSelectUser={(userId) => {
              handleSwitchUser(userId);
              setCurrentTab('feed');
            }}
            onRequestOtp={handleRequestOtp}
            onNavigateToSignup={() => setCurrentTab('signup')}
            onNavigateToAdmin={() => setCurrentTab('admin')}
            onLoginLater={handleLoginLater}
          />
        )}

        {currentTab === 'otp' && (
          <OtpScreen
            phoneNumber={pendingPhone}
            onVerify={handleVerifyOtp}
            onBack={() => setCurrentTab('login')}
          />
        )}

        {currentTab === 'signup' && (
          <SignupScreen
            parties={parties}
            onRegister={handleRegister}
            onBackToLogin={() => setCurrentTab('login')}
          />
        )}
      </div>

      {/* Create Post Modal */}
      <CreatePostModal
        currentUser={currentUser}
        parties={parties}
        isOpen={isCreatePostOpen}
        onClose={() => setIsCreatePostOpen(false)}
        onSubmit={handleCreatePost}
      />

      {/* Create Poll Modal — rendered OUTSIDE PartyProfileScreen so it renders
          after CreatePostModal in DOM and is never covered by it. */}
      {currentTab === 'party' && showCreatePoll && (() => {
        const party = parties.find((p) => p.id === activePartyId) || parties[0];
        return (
          <CreatePollModal
            key="create-poll"
            party={party}
            currentUser={currentUser}
            onClose={() => setShowCreatePoll(false)}
            onCreate={(newPoll) => {
              const created = storageService.createPoll(newPoll);
              if (created) {
                setPolls(storageService.getPolls());
                showToast('Poll posted for verified members to vote.');
              } else {
                showToast('Could not post poll. Please try again.');
              }
              setShowCreatePoll(false);
            }}
          />
        );
      })()}
    </div>
  );
};
