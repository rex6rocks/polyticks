## Phase 1: Foundation & Data Security (Do First)

**Task 3.1** — Database & Schema Updates for Clustering & Polls (Agent
Antigravity)

    Why: Establishes the exact database contract, state structures, and RLS security rules first.

## Phase 2: Visual Layouts & Mock Components (Do Second)

**Task 3.2** — Dual-Feed Navigation UI & Filtering (Agent Aider)

    Why: Builds the raw UI layout components against the verified schema using dummy/mock parameters so the UI is stable and context-isolated.

## Phase 3: Service Wiring & Edge Logic (Do Last)

**Task 3.3** — Viral Claim Sharing & Dynamic Image Generator (Agent Cline)

## --------------------------------------

Here is an in-depth, technical execution guide specifically for Version 3.0,
broken down by team roles as actionable epics and tasks.

## --------------------------------------

🚀 Polyticks V3.0 Technical Implementation Guide

Context for the Team: Version 3.0 shifts our focus to Hyper-Local Clustering and
Organic Virality. We are exclusively targeting Android and Flutter Web (iOS has
been deferred to v5.0). The core objective is to segment users into physical
communities, allow verified polling within those communities, and generate
dynamic image previews to drive viral sharing on WhatsApp and X (Twitter).

🛠️ EPIC 1: Database & Schema Engineering

Assignee: Antigravity (Backend / Database Admin)
Objective: Update the PostgreSQL schema in Supabase to support geographic segmentation, tamper-proof polling, and org claiming.

Task 1.1: Schema Migrations (Clustering & Claiming)

- Action: Execute SQL migrations to create community/ward tables and update profiles and posts tables.
- Technical Details:
  ```sql
  -- 1. Communities and Wards Infrastructure
  CREATE TABLE IF NOT EXISTS public.communities (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      name TEXT NOT NULL,
      state TEXT NOT NULL,
      postal_code TEXT,
      created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
  );

  CREATE TABLE IF NOT EXISTS public.wards (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      community_id UUID REFERENCES public.communities(id) ON DELETE CASCADE,
      name TEXT NOT NULL,
      ward_number INTEGER,
      created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
  );

  -- 2. Claim Status Enum & Profile Updates
  DO $$ BEGIN
      CREATE TYPE claim_status_type AS ENUM ('unclaimed', 'claim_pending', 'claimed');
  EXCEPTION
      WHEN duplicate_object THEN null;
  END $$;

  ALTER TABLE public.profiles 
      ADD COLUMN IF NOT EXISTS community_id UUID REFERENCES public.communities(id),
      ADD COLUMN IF NOT EXISTS ward_id UUID REFERENCES public.wards(id),
      ADD COLUMN IF NOT EXISTS claim_status claim_status_type DEFAULT 'unclaimed',
      ADD COLUMN IF NOT EXISTS official_email TEXT;

  ALTER TABLE public.posts 
      ADD COLUMN IF NOT EXISTS community_id UUID REFERENCES public.communities(id),
      ADD COLUMN IF NOT EXISTS ward_id UUID REFERENCES public.wards(id);
  ```

Task 1.2: Polling Engine Schema

- Action: Create the robust, strictly-typed polling schema.
- Technical Details:
  ```sql
  -- 1. Create Polls Table
  CREATE TABLE IF NOT EXISTS public.polls (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
      question TEXT NOT NULL,
      created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
  );

  -- 2. Create Poll Options Table
  CREATE TABLE IF NOT EXISTS public.poll_options (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      poll_id UUID NOT NULL REFERENCES public.polls(id) ON DELETE CASCADE,
      option_text TEXT NOT NULL,
      vote_count INTEGER DEFAULT 0 NOT NULL
  );

  -- 3. Create Poll Votes Table (Tamper-Proofing)
  CREATE TABLE IF NOT EXISTS public.poll_votes (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      poll_id UUID NOT NULL REFERENCES public.polls(id) ON DELETE CASCADE,
      option_id UUID NOT NULL REFERENCES public.poll_options(id) ON DELETE CASCADE,
      voter_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
      created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
      CONSTRAINT unique_user_poll_vote UNIQUE (poll_id, voter_id) -- Enforces 1-vote-per-user
  );
  ```

Task 1.3: Row-Level Security (RLS) Policies & Triggers for Polls

- Action: Write PostgreSQL RLS policies ensuring public read access and verified community member vote permissions, along with real-time tally triggers.
- Technical Details:
  ```sql
  -- Enable RLS
  ALTER TABLE public.communities ENABLE ROW LEVEL SECURITY;
  ALTER TABLE public.wards ENABLE ROW LEVEL SECURITY;
  ALTER TABLE public.polls ENABLE ROW LEVEL SECURITY;
  ALTER TABLE public.poll_options ENABLE ROW LEVEL SECURITY;
  ALTER TABLE public.poll_votes ENABLE ROW LEVEL SECURITY;

  -- Public Read Policies (Allow viewing by everyone, including unverified users)
  CREATE POLICY "Communities viewable by everyone" ON public.communities FOR SELECT USING (true);
  CREATE POLICY "Wards viewable by everyone" ON public.wards FOR SELECT USING (true);
  CREATE POLICY "Polls viewable by everyone" ON public.polls FOR SELECT USING (true);
  CREATE POLICY "Poll options viewable by everyone" ON public.poll_options FOR SELECT USING (true);
  CREATE POLICY "Poll votes viewable by everyone" ON public.poll_votes FOR SELECT USING (true);

  -- Verified community members can vote
  CREATE POLICY "Verified community members can vote" ON public.poll_votes 
  FOR INSERT WITH CHECK (
      auth.uid() = voter_id
      AND EXISTS (
          SELECT 1 FROM public.profiles 
          WHERE id = auth.uid() AND is_verified = true
      )
      AND (
          -- If post has a community_id, voter's community_id must match
          (SELECT community_id FROM public.posts WHERE id = (SELECT post_id FROM public.polls WHERE id = poll_id)) IS NULL
          OR
          (SELECT community_id FROM public.profiles WHERE id = auth.uid()) = 
          (SELECT community_id FROM public.posts WHERE id = (SELECT post_id FROM public.polls WHERE id = poll_id))
      )
  );

  -- Trigger to automatically increment/decrement vote_count in poll_options
  CREATE OR REPLACE FUNCTION public.handle_poll_vote_change()
  RETURNS trigger AS $$
  BEGIN
      IF (TG_OP = 'INSERT') THEN
          UPDATE public.poll_options 
          SET vote_count = vote_count + 1 
          WHERE id = NEW.option_id;
      ELSIF (TG_OP = 'DELETE') THEN
          UPDATE public.poll_options 
          SET vote_count = GREATEST(0, vote_count - 1) 
          WHERE id = OLD.option_id;
      END IF;
      RETURN NULL;
  END;
  $$ LANGUAGE plpgsql SECURITY DEFINER;

  DROP TRIGGER IF EXISTS on_poll_vote_inserted_or_deleted ON public.poll_votes;
  CREATE TRIGGER on_poll_vote_inserted_or_deleted
      AFTER INSERT OR DELETE ON public.poll_votes
      FOR EACH ROW EXECUTE FUNCTION public.handle_poll_vote_change();
  ```

🎨 EPIC 2: Frontend & UI Components

Assignee: Aider / Junior Dev (Flutter UI)
Objective: Build the new dual-feed interface, community selector, and interactive poll cards in the existing Flutter codebase (`lib/`).

Architecture Context:
- State Management: `flutter_riverpod`
- Data Service: `SupabaseService` (`lib/services/supabase_service.dart`) supporting dual mode (Real Supabase + Simulation fallback)
- User Roles: `UserRole.janta` (Citizen), `UserRole.leader`, `UserRole.party`, `UserRole.journalist`, `UserRole.admin`

Task 2.1: Dual-Feed Top Navigation

- Action: Refactor `lib/screens/feed/feed_screen.dart` to support tabbed navigation.
- Technical Details:
  - Implement a `DefaultTabController` or custom segmented toggle at the top of the AppBar in `lib/screens/feed/feed_screen.dart`.
  - Tab 1: "My Community" (Hyper-Local Feed)
  - Tab 2: "National" (Broader Feed)
  - State requirement: When toggling tabs, pass the selected filter (`hyperLocal: true` with `currentUser.communityId` vs `hyperLocal: false`) to `SupabaseService.instance.getPosts()` or Riverpod feed provider.

Task 2.2: Community Selector Modal

- Action: Create `lib/widgets/community_selector_dialog.dart` (or integrate in `lib/widgets/shared_widgets.dart`).
- Technical Details:
  - A `showModalBottomSheet` containing a searchable `ListView` of available communities/wards.
  - Allow unassigned users to select their community (updates `community_id` in `profiles` and local `AppUser`).
  - Include a "Request my community" text button for users whose community isn't listed.

Task 2.3: Interactive Community Poll Card

- Action: Enhance `lib/widgets/poll_widget.dart` and `lib/widgets/post_card.dart` for embedded poll cards.
- Technical Details:
  - UI must display the question at the top.
  - Map through `pollOptions` and render clickable option rows.
  - If the user has voted or is unverified, UI displays "Results Mode": Display a `LinearProgressIndicator` behind each option text.
  - Math: Calculate percentage: `(option.voteCount / totalVotes) * 100`.
  - Ensure smooth animation of the progress bar upon rendering.

⚙️ EPIC 3: Logic, Integrations & Viral Engine

Assignee: Cline / Mid-Level Integrator (Flutter Logic / Edge Functions)
Objective: Wire up the UI to `SupabaseService`, handle optimistic state updates, and build dynamic image generation for WhatsApp/X virality.

Task 3.1: Dual-Feed Wiring & Optimistic Poll State

- Action: Update `lib/services/supabase_service.dart` and handle real-time UI updates via Riverpod.
- Technical Details:
  - Feed Query: Modify `getPosts({bool hyperLocal = false, String? communityId})`.
    - Real Supabase: When `hyperLocal && communityId != null`, add `.eq('community_id', communityId)` to query; when national, query `.isFilter('community_id', null)`.
    - Simulation Fallback: Filter `_simulatedPosts` accordingly so mock/offline runs pass seamlessly.
  - Optimistic Poll Voting in `SupabaseService.voteInPoll(String userId, String pollId, String optionId)`:
    1. Immediately increment `voteCount` locally in `_simulatedPosts` / Riverpod state.
    2. Set `userPollVoteOptionId` locally to instantly trigger UI "Results Mode" (Task 2.3).
    3. Make async call to insert into `poll_votes`.
    4. Error Handling: If Supabase call fails (e.g. unverified user or double vote), catch error, revert local state, and show a `SnackBar` ("Action failed: Ensure you are a verified community member").
  - Privacy & Purging Preservation: Maintain auto-purging of verification ID documents in `approveVerification` / `rejectVerification` (`storage.from('id-verifications').remove([filename])`).

Task 3.2: Dynamic Social Preview Cards (Edge Function)

- Action: Create a Supabase Edge Function to generate .png preview cards
  dynamically (Open Graph Images).
- Technical Details:
  - Constraint: Supabase Edge Functions run on Deno. Since canvas can be heavy,
    the standard approach is using Satori (HTML/CSS to SVG) + Resvg (SVG to PNG)
    inside Deno.
  - Create an endpoint: POST /generate-share-card
  - Accepts post_id. Fetches post text, author handle, and fact_check_status.
  - Generate an image displaying:
    - App Logo (Polyticks).
    - The Post Text (truncated if too long).
    - A banner at the bottom: "Verified by Community" (if fact-checked) or "Join
      the Poll on Polyticks".
  - Upload the generated PNG to a public Supabase Storage bucket
    (share_previews) and return the public URL.

Task 3.3: WhatsApp & Deep Link Sharing

- Action: Wire share_plus and Deep Linking in Flutter.
- Technical Details:
  - Implement Share.share() when a user clicks the share icon.
  - The payload should be a formatted string: "Check out this local poll on
    Polyticks: [Post Title]... Read more: https://polyticks.app/post/{post_id}"
  - Web App specific: Ensure the <head> of the web app route /post/:id updates
    its <meta property="og:image"> to the dynamic image URL generated in Task
    3.2. This ensures that when the link is pasted into WhatsApp or X, the
    dynamic image unfurls automatically.

✅ V3.0 Definition of Done (Testing Criteria)

1. Security: A user cannot vote twice on a poll (DB unique constraint throws an
   error).
2. Access: Unverified users viewing a local community feed can see the poll
   results but get rejected if they try to vote.
3. Virality: Copying a post link and pasting it into a WhatsApp chat
   successfully fetches the dynamically generated PNG showing the post text and
   Fact-Check banner.
4. Performance: Toggling between "Local" and "National" feeds is snappy and
   correctly filters by community_id.
