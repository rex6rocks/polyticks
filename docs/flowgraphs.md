# Polyticks — Full Application Flow Graphs & Architecture Specification (v4.0 + Fixes)

> **Generated:** 2026-08-30  
> **Source of Truth:** Flutter Codebase (`lib/`)  
> **Scope:** Full application routing, user roles (`Janta`, `Party Member`, `Party Official`, `Admin Moderator`), authentication, identity verification (DigiLocker/Manual), civic feed, reaction & fact-check engine, moderation SLA, party hierarchy, B2B subscriptions, Right-of-Reply portal, and analytics dashboard.

---

## 1. System Role Matrix & Capabilities

| Role | Verification State | Primary Capabilities & Gating |
| :--- | :--- | :--- |
| **Guest Janta** | Unverified (Synthetic) | Read public feeds/posts/polls; restricted from creating posts, voting on polls, reacting, or submitting fact checks. |
| **Unverified Janta** | Unverified / Pending | Directed to `IdVerificationScreen` on sign-in; read feeds, update basic profile; posting & voting restricted until verified. |
| **Verified Janta** | Verified (DigiLocker / Admin approved) | Full civic participation: post in Hyper-Local & Broader channels (280 chars), like/dislike all posts, vote in public polls, submit community notes (`SubmitFactCheckModal`), report content. |
| **Party Member** | Verified (Tier 1–9) | All Janta capabilities + auto-follow own party, post in party channels, vote in party-exclusive polls, hold hierarchy tier (`PartyRole` tiers 1–9). Higher tiers can assign/revoke subordinate member roles. |
| **Party Official** | Verified (Org Account) | Manage party profile, create official party posts & ballot polls, assign top-tier roles (1-5), access `OrgSubscriptionScreen` (Razorpay Gold/Platinum), publish official statements via `RightOfReplyPortal`, view `AnalyticsDashboard`. Cannot react to own org posts. |
| **Admin Moderator**| Verified System Admin | Routes directly to `AdminConsoleScreen`; manage ID verification queue (with zero-retention document auto-purge & audit logs), review content moderation SLA queue (`AdminModerationQueueScreen`), resolve flagged/auto-hidden posts. |

---

## 2. App Entry Point & Conditional Navigation Flow Graph

```mermaid
graph TD
    A[App Launch: main.dart line 20] --> B[WidgetsFlutterBinding.ensureInitialized line 21]
    B --> C[SupabaseService.initialize line 24]
    C --> D[_bindAppLinks line 45: Bind DeepLinkHandler]
    D --> E[ProviderScope > PolyticksApp line 42]
    E --> F{_currentUser State line 96}
    
    F -->|currentUser == null| G[LoginScreen: lib/screens/auth/login_screen.dart line 97]
    F -->|role == Admin| H[AdminConsoleScreen: lib/screens/admin/admin_console_screen.dart line 99]
    F -->|Janta & !isVerified & !isGuest| I[IdVerificationScreen: lib/screens/auth/id_verification_screen.dart line 101]
    F -->|Verified Janta / Party Member / Party Official| J[FeedScreen: lib/screens/feed/feed_screen.dart line 106]

    G -->|Phone OTP Authenticated| K[_onLogin Callback: line 73]
    G -->|Demo Persona Selected| K
    G -->|Guest Login| K
    
    K -->|Update _currentUser & _showIdVerification| F
```

- **File Reference:** `lib/main.dart`
  - `main()`: lines 20–44
  - `_bindAppLinks()`: lines 45–60
  - `_PolyticksAppState.build()`: lines 94–118

---

## 3. Authentication & Identity Verification Flows

### 3.1 Authentication & Persona Simulation Flow Graph

```mermaid
graph TD
    Sub1[LoginScreen: lib/screens/auth/login_screen.dart] --> Choice{User Action}
    
    Choice -->|Enter Phone & Tap Send OTP| PhoneOTP[_sendOtp: line 33]
    Choice -->|Tap 'Continue as Guest'| Guest[_loginAsGuest: line 72]
    Choice -->|Tap Demo Persona| Persona[_loginAsPersona: line 98]
    Choice -->|Tap Admin Console Quick-Button| Admin[_loginAsAdmin: line 85]
    Choice -->|Tap 'Sign Up'| SignupNav[Navigate to SignupScreen: lib/screens/auth/signup_screen.dart]

    PhoneOTP -->|SupabaseService.sendOTP| OTPNav[Push OTPVerificationScreen: lib/screens/auth/otp_verification_screen.dart line 60]
    OTPNav -->|Submit 6-Digit OTP| OTPVerify[AuthService.verifyOTP / Supabase Auth]
    OTPVerify -->|Success| AuthSuccess[Trigger onAuthenticated -> Main _onLogin]

    Guest -->|AppUser role=janta, isGuest=true| AuthSuccess
    Persona -->|Fetch profile / authenticate| AuthSuccess
    Admin -->|AppUser role=admin| AuthSuccess
```

- **File References:**
  - `lib/screens/auth/login_screen.dart`: `_sendOtp`, `_loginAsGuest`, `_loginAsAdmin`, `_loginAsPersona`
  - `lib/screens/auth/signup_screen.dart`
  - `lib/screens/auth/otp_verification_screen.dart`
  - `lib/services/auth_service.dart`

---

### 3.2 Government ID & DigiLocker eKYC Flow Graph

```mermaid
graph TD
    IDScreen[IdVerificationScreen: lib/screens/auth/id_verification_screen.dart] --> ModeChoice{Verification Method}
    
    ModeChoice -->|Instant Verification| DigiLocker[DigiLocker CTA: line 150]
    ModeChoice -->|Manual Document Upload| ManualUpload[Pick ID Image from Gallery/Camera: line 200]

    DigiLocker --> DigiInit[DigiLockerVerificationService.initiateVerification: line 35]
    DigiInit --> DigiWeb[Open OAuth / eKYC Callback Bridge]
    DigiWeb --> DigiFinal[DigiLockerVerificationService.finalizeVerification: line 75]
    DigiFinal -->|Success| InstApproved[Profile status -> approved, role -> verified_user]

    ManualUpload --> Compress[ImageCompressor.compressImage: lib/services/image_compressor.dart line 15]
    Compress -->|Result < 150 KB JPEG| IDService[IDVerificationService.uploadIDVerification: lib/services/id_verification_service.dart line 40]
    IDService --> Storage[Upload to private 'id-verifications' bucket]
    Storage --> DBReq[Insert verification_requests row, profile status -> pending]
    DBReq --> StatusNav[Push VerificationStatusScreen: lib/screens/auth/verification_status_screen.dart]
```

- **File References:**
  - `lib/screens/auth/id_verification_screen.dart`
  - `lib/screens/auth/verification_status_screen.dart`
  - `lib/services/digilocker_verification_service.dart`
  - `lib/services/id_verification_service.dart`

---

## 4. Civic Feed & Interaction Engine Flows

### 4.1 Dual Feed & Channel Filtering Flow Graph

```mermaid
graph TD
    Feed[FeedScreen: lib/screens/feed/feed_screen.dart] --> ChannelToggle{Channel Selected}
    
    ChannelToggle -->|Hyper-Local Channel| Local[Filter by User communityId]
    ChannelToggle -->|Broader Channel| Broader[Aggregate across all communities]

    Feed --> CommSelector[Tap Community Badge -> CommunitySelectorDialog: lib/widgets/community_selector_dialog.dart]
    CommSelector -->|Select Ward/District| SwitchComm[Update active communityId -> Refresh Feed]

    Feed --> PostCreateBtn[Tap + Create Post]
    PostCreateBtn -->|Check Gating| CreateCheck{User Role & Verification}
    CreateCheck -->|Guest / Unverified| DenyToast[Show Snackbar: Verification Required]
    CreateCheck -->|Verified User| OpenModal[Open CreatePostModal: lib/widgets/create_post_modal.dart]
```

- **File References:**
  - `lib/screens/feed/feed_screen.dart`
  - `lib/widgets/community_selector_dialog.dart`
  - `lib/widgets/create_post_modal.dart`

---

### 4.2 Post Creation & AI Safety Screening Flow Graph

```mermaid
graph TD
    Modal[CreatePostModal: lib/widgets/create_post_modal.dart] --> Input[Enter Content max 280 chars & Select Channel]
    Input --> Submit[Tap Submit Post]
    
    Submit --> AIScreen[AIModerationService.screenContent: lib/services/ai_moderation_service.dart]
    AIScreen --> RiskCheck{AI Risk Evaluation}
    
    RiskCheck -->|Flagged Hate/Violent Speech| BlockPost[Reject post submission & show error banner]
    RiskCheck -->|Pass / Fail-Open Outage| SavePost[SupabaseService.createPost: lib/services/supabase_service.dart]
    SavePost --> UpdateFeed[Prepend post to local feed & close modal]
```

- **File References:**
  - `lib/widgets/create_post_modal.dart`
  - `lib/services/ai_moderation_service.dart`
  - `lib/services/supabase_service.dart`

---

### 4.3 Optimistic Reaction Engine & Dislike Trigger Flow Graph

```mermaid
graph TD
    Card[PostCard: lib/widgets/post_card.dart] --> ReactChoice{User Action: Like / Dislike}
    
    ReactChoice --> GateCheck{Role Check}
    GateCheck -->|Party Official on own post| BlockReact[Action Blocked: Party cannot react to own posts]
    GateCheck -->|Verified Citizen / Party Member| OptUpdate[Optimistically increment count & flip toggle in UI]

    OptUpdate --> DBSync[SupabaseService.toggleReaction: lib/services/supabase_service.dart]
    DBSync --> Triggers[DB Trigger: 04_v2_triggers.sql]
    
    Triggers --> ThresholdCheck{Dislike Ratio > 60% & Total Votes >= 25}
    ThresholdCheck -->|Yes| UnderReview[Set fact_check_status = 'under_review']
    UnderReview --> RenderBanner[Render UnderReviewBanner: lib/widgets/under_review_banner.dart]
```

- **File References:**
  - `lib/widgets/post_card.dart`
  - `lib/widgets/under_review_banner.dart`

---

### 4.4 Crowd Fact-Checking & Community Notes Flow Graph

```mermaid
graph TD
    Card[PostCard: lib/widgets/post_card.dart] --> OptionMenu[Tap Post Options / Fact Check]
    OptionMenu --> VerifiedCheck{Is User Verified?}
    
    VerifiedCheck -->|No| ErrVerif[Show VerificationRequiredException Toast]
    VerifiedCheck -->|Yes| OpenFC[Open SubmitFactCheckModal: lib/widgets/submit_fact_check_modal.dart]

    OpenFC --> FCInput[Enter Context Note & Source URLs]
    FCInput --> SubmitFC[FactCheckService.submitNote: lib/services/fact_check_service.dart]
    SubmitFC --> RefreshNotes[CommunityNotesSection fetches live notes: lib/widgets/community_notes_section.dart]

    RefreshNotes --> VoteNote[Users Upvote / Downvote Context Note]
    VoteNote --> NetCheck{Net Upvote Score >= 10}
    NetCheck -->|Yes| PromoteContext[Promote Note -> FactCheckStatus.verifiedContext]
    PromoteContext --> RenderPromoted[Render Promoted Context Banner on PostCard]
```

- **File References:**
  - `lib/widgets/submit_fact_check_modal.dart`
  - `lib/widgets/community_notes_section.dart`
  - `lib/services/fact_check_service.dart`

---

### 4.5 Content Reporting & 24h SLA Auto-Hide Flow Graph

```mermaid
graph TD
    Card[PostCard: lib/widgets/post_card.dart] --> TapReport[Tap Report Post]
    TapReport --> RepDialog[ReportContentDialog: lib/widgets/report_content_dialog.dart]
    RepDialog --> SelectReason[Select Reason: Spam, Misinformation, Hate Speech, Other]
    SelectReason --> SendReport[ReportService.submitReport: lib/services/report_service.dart]
    
    SendReport --> SurgeTrigger[DB Trigger: 07_v2_sla_auto_hide.sql]
    SurgeTrigger --> CountCheck{Report Count >= 5 in last 24 Hours?}
    
    CountCheck -->|Yes| AutoHide[Set fact_check_status = 'auto_hidden' & is_hidden = true]
    AutoHide --> QueueInsert[Insert row into Admin Moderation Queue with 24h SLA Countdown]
    AutoHide --> FilterFeed[Post automatically filtered out from public feeds]
```

- **File References:**
  - `lib/widgets/report_content_dialog.dart`
  - `lib/services/report_service.dart`
  - `lib/screens/admin/admin_moderation_queue_screen.dart`

---

## 5. Party Profiles & Hierarchy Management

### 5.1 Party Hierarchy (`PartyRole` Tiers 1-9)
The application establishes a strict 9-tier hierarchy defined in `lib/models/models.dart`:
- **Tier 1:** President
- **Tier 2:** Vice President
- **Tier 3:** Executive Committee
- **Tier 4:** General Secretary
- **Tier 5:** Treasurer
- **Tier 6:** State President
- **Tier 7:** District President
- **Tier 8:** Mandal Level Officer
- **Tier 9:** Ground Worker

**Top-Tier Constraint:** Tiers 1–5 can ONLY be assigned by the verified `Party Official` account. Subordinate tiers (6-9) can be assigned by members of a higher tier.

### 5.2 Party Profile Flow Graph
```mermaid
graph TD
    PartyProfile[PartyProfileScreen: lib/screens/party/party_profile_screen.dart] --> RoleActions{Viewer Role}
    
    RoleActions -->|Janta User| FollowBtn[Toggle Follow / Unfollow Party]
    RoleActions -->|Janta User| JoinBtn[Submit Join Request to Party]
    RoleActions -->|Party Member| MemberLock[Auto-Followed; Unfollow Disabled while Member]
    RoleActions -->|Party Official / Admin| OrgBar[Render Org Management Quick Bar]

    PartyProfile --> TabSwitch{Select Profile Tab}
    TabSwitch -->|Posts Tab| PartyPosts[Filter and display posts by partyId]
    TabSwitch -->|Polls Tab| PartyPolls[Display PollWidget list: lib/widgets/poll_widget.dart]
    TabSwitch -->|Members Tab| HierarchyList[Display Party Hierarchy: Tiers 1–9]

    HierarchyList --> RoleMgmt{Viewer Authority}
    RoleMgmt -->|Official Account / Higher Tier| AssignRole[PartyMembershipService.assignRole: lib/services/party_membership_service.dart]
    RoleMgmt -->|Subordinate Role| ViewOnly[Read-Only Tier Badge display]

    OrgBar -->|Tap Subscription| SubScreen[Push OrgSubscriptionScreen: lib/screens/org/subscription_screen.dart]
    OrgBar -->|Tap Right-of-Reply| RoRScreen[Push RightOfReplyPortal: lib/screens/org/right_of_reply_portal.dart]
    OrgBar -->|Tap Analytics| AnalyticsScreen[Push OrgAnalyticsDashboard: lib/screens/org/analytics_dashboard.dart]
```

- **File References:**
  - `lib/screens/party/party_profile_screen.dart`
  - `lib/widgets/poll_widget.dart`
  - `lib/services/party_membership_service.dart`

---

## 6. Post Detail, Threaded Comments & Deep Linking Flows

```mermaid
graph TD
    DeepLink[DeepLinkHandler: lib/services/deep_link_service.dart] -->|Uri: polyticks://post/:id or web /post/:id| ResolvePost[Fetch post by ID via SupabaseService]
    ResolvePost --> PushDetail[Push PostDetailScreen: lib/screens/post/post_detail_screen.dart]
    
    PostDetailScreen --> RenderCard[Render Main PostCard with full text]
    PostDetailScreen --> RenderRoR[Render OfficialReplyBanner if org statement exists: lib/widgets/official_reply_banner.dart]
    PostDetailScreen --> RenderComments[Render CommentThread widget: lib/widgets/comment_thread.dart]

    RenderComments --> AddComment[Submit Comment / Reply to Parent Comment]
    AddComment --> SaveComment[SupabaseService.addComment: unlimited nested depth via parentId]
    SaveComment --> RefreshThread[Re-render nested comment list]
```

- **File References:**
  - `lib/screens/post/post_detail_screen.dart`
  - `lib/widgets/comment_thread.dart`
  - `lib/widgets/official_reply_banner.dart`
  - `lib/services/deep_link_service.dart`

---

## 7. Admin Governance & Moderation Console Flows

### 7.1 ID Verification Queue & Zero-Retention Auto-Purge Graph

```mermaid
graph TD
    AdminConsole[AdminConsoleScreen: lib/screens/admin/admin_console_screen.dart] --> TabSelect{Admin Tab}
    
    TabSelect -->|ID Verifications Tab| IDQueue[Fetch pending verification_requests]
    TabSelect -->|Audit Logs Tab| AuditView[View zero-retention deletion logs & SLA breaches]

    IDQueue --> ReviewDoc[Preview ID document via signed Supabase Storage URL]
    ReviewDoc --> AdminDec{Admin Decision}

    AdminDec -->|Approve| ApproveReq[Update profile: is_verified = true, role = verified_user / partyMember]
    AdminDec -->|Reject| RejectReq[Update request status = rejected with reason]

    ApproveReq --> AutoPurge[IDVerificationService.purgeDocument: lib/services/id_verification_service.dart]
    RejectReq --> AutoPurge

    AutoPurge --> PurgeStorage[Delete document binary from 'id-verifications' bucket]
    PurgeStorage --> LogAudit[Insert row into purge_audit_logs DB table]
```

- **File References:**
  - `lib/screens/admin/admin_console_screen.dart`
  - `lib/services/id_verification_service.dart`
  - `lib/services/admin_moderation_service.dart`

---

### 7.2 Content Moderation SLA Queue Graph

```mermaid
graph TD
    ModQueue[AdminModerationQueueScreen: lib/screens/admin/admin_moderation_queue_screen.dart] --> FetchQueue[AdminModerationService.fetchFlaggedPosts: lib/services/admin_moderation_service.dart]
    
    FetchQueue --> SortSLA[Calculate remaining SLA countdown & sort by SlaUrgency: normal, warning, critical, breached]
    SortSLA --> FilterQueue[Apply filters by status or urgency]

    FilterQueue --> ItemAction{Admin Action}
    
    ItemAction -->|Approve Content| ModApprove[AdminModerationService.approveContent]
    ItemAction -->|Reject / Take Down| ModReject[AdminModerationService.rejectContent]

    ModApprove --> RestoreDB[Set is_hidden = false, fact_check_status = 'verified_context', clear reports]
    ModReject --> LockHidden[Keep is_hidden = true, status = 'disputed', flag author account]
```

- **File References:**
  - `lib/screens/admin/admin_moderation_queue_screen.dart`
  - `lib/services/admin_moderation_service.dart`

---

## 8. Monetization, B2B Analytics & Right-of-Reply Flows (v4.0 Spec)

```mermaid
graph TD
    OrgPortal[Org Management Portal: PartyProfileScreen Quick Bar] --> Choice{Selected Portal Tool}
    
    Choice -->|Subscription Plans| SubScreen[SubscriptionScreen: lib/screens/org/subscription_screen.dart]
    Choice -->|Right-of-Reply Portal| RoRPortal[RightOfReplyPortal: lib/screens/org/right_of_reply_portal.dart]
    Choice -->|Campaign Analytics| AnalyticsDash[AnalyticsDashboard: lib/screens/org/analytics_dashboard.dart]

    SubScreen --> TierSelect[Select Tier: Basic $0, Gold $10/mo, Platinum $50/mo]
    TierSelect --> RzpCheckout[RazorpayCheckoutService.openSubscriptionSheet: lib/services/razorpay_checkout_service.dart]
    RzpCheckout --> RzpWebhook[Supabase Edge Fn: payment-webhook -> updates subscriptions table]
    RzpWebhook --> BadgeRender[Render OrgTierBadge on Party Profile & Post Cards: lib/widgets/org_tier_badge.dart]

    RoRPortal --> QueuePosts[Fetch flagged/disputed org posts via RightOfReplyService: lib/services/right_of_reply_service.dart]
    QueuePosts --> ComposeReply[Compose official response statement]
    ComposeReply --> PublishReply[Set status = 'published' -> Renders OfficialReplyBanner on public post cards]

    AnalyticsDash --> FetchStats[AnalyticsService.fetchOrgAnalytics: lib/services/analytics_service.dart]
    FetchStats --> QueryViews[Read security_invoker view: org_analytics_summary]
    QueryViews --> RenderMetrics[Render Trust Score Gauge, Impression Stats, and Fact-Check Outcome Breakdown]
```

- **File References:**
  - `lib/screens/org/subscription_screen.dart`
  - `lib/screens/org/right_of_reply_portal.dart`
  - `lib/screens/org/analytics_dashboard.dart`
  - `lib/widgets/org_tier_badge.dart`
  - `lib/widgets/official_reply_banner.dart`
  - `lib/services/subscription_service.dart`
  - `lib/services/razorpay_checkout_service.dart`
  - `lib/services/right_of_reply_service.dart`
  - `lib/services/analytics_service.dart`

---

## 9. State Management & Riverpod Optimistic Data Flows

The application heavily utilizes Riverpod (`flutter_riverpod`) for managing asynchronous states and optimistic UI updates to ensure a highly responsive interface.

### 9.1 Poll Voting & Optimistic Update Flow
```mermaid
graph TD
    UI[PollWidget UI] --> TapVote[User Taps Option ID]
    TapVote --> RefNotifier[pollProvider.notifier.vote: lib/providers/poll_provider.dart]
    
    RefNotifier --> CacheUpdate[StateNotifier maps current state: option.votes + 1]
    CacheUpdate --> UpdateUI[Synchronously update state -> UI flips to 'Results Mode' instantly]
    
    UpdateUI --> DbSync[SupabaseService.voteInPoll: network request to insert vote row]
    DbSync --> Result{DB Insert Success?}
    
    Result -->|Success| KeepState[Optimistic state remains permanent]
    Result -->|Failure / RLS Block| RevertState[StateNotifier reverts to previousState]
    RevertState --> ShowToast[UI handles boolean return 'false' -> Shows Error Toast]
```

### 9.2 Content Moderation State Flow
```mermaid
graph TD
    Queue[AdminModerationQueueScreen] --> RefWatch[ref.watch(moderationNotifierProvider): lib/providers/moderation_provider.dart]
    RefWatch --> AsyncVal{AsyncValue State}
    
    AsyncVal -->|Loading| Spinner[Show ProgressIndicator]
    AsyncVal -->|Data| RenderQueue[Render ModerationState: filter, queue list, lastRefreshed]
    
    RenderQueue --> Action[Admin taps 'Approve / Reject']
    Action --> NotifierGuard[ModerationNotifier.resolveReport wraps logic in AsyncValue.guard]
    NotifierGuard --> AdminSvc[AdminModerationService DB update]
    AdminSvc --> RemapState[currentState.copyWith: filter out the resolved postId]
    RemapState --> RebuildUI[Screen rebuilds automatically without the resolved item]
```

- **File References:**
  - `lib/providers/poll_provider.dart`
  - `lib/providers/moderation_provider.dart`
  - `lib/providers/auth_provider.dart`

---

## 10. Codebase & Documentation Audit / Discrepancy Reconciliation

During this complete review of the v4.0 implementation codebase, the following documentation alignment points were verified:

1. **`docs/heart.md` (Line 8)**:
   - *Doc Statement:* Listed `lib/main.dart -> lib/screens/auth/login_screen.dart` as the sole entry point.
   - *Current Implementation:* `lib/main.dart` (lines 95–110) implements dynamic entry routing based on role and verification state (`LoginScreen`, `AdminConsoleScreen`, `IdVerificationScreen`, `FeedScreen`).
   - *Action:* Updated flowgraph in Section 2 accurately reflects this multi-branch routing logic.

2. **`docs/brain.md` (Line 5)**:
   - *Doc Statement:* Summarized state flow as `UI -> Riverpod Providers -> Services -> Supabase`.
   - *Current Implementation:* Core services (`SupabaseService`, `FactCheckService`, `SubscriptionService`, `AnalyticsService`) use Riverpod providers (`auth_provider.dart`, `fact_check_provider.dart`, `moderation_provider.dart`, `poll_provider.dart`) alongside direct singleton contracts for offline simulation mode (`AppConfig.forceTestMode`).
   - *Action:* Added Section 9 to explicitly graph how Riverpod `StateNotifier` operates for optimistic UI updates.

3. **`docs/V4_SPEC.md` & `ProjectTracker.md`**:
   - All v4.0 deliverables (DigiLocker mock bridge, Razorpay subscription checkout, B2B analytics rollups, Right-of-Reply portal, registration-lock trigger) are fully built in `lib/` and verified with 0 linter errors.
   - Future post-launch / v4.1 config items (such as live DigiLocker production credentials & live Razorpay keys) remain isolated in configuration flags (`lib/config.dart`).
