---
name: Social Features & Supabase Backend Plan
description: Comprehensive plan for user registration, social features (profiles, groups, leaderboards, challenges, feed), and Supabase backend integration — saved for future implementation
type: project
---

Full plan saved at: `/Users/sergeymuzyukin/.claude/plans/whimsical-juggling-hopper.md`

**Decision: Supabase** as backend (PostgreSQL, REST+WebSocket, no SPM packages, zero external deps maintained)

**7 phases planned:**
1. Foundation — pure-Swift Supabase client, multi-auth (Apple+Google), JWT management
2. User Profiles — public stats, avatar, badges
3. Social Graph — follow/unfollow, user search, Social tab replaces Settings tab
4. Sharing — workout/template/plan sharing via deep links, community library
5. Groups — clubs with group feed
6. Leaderboards & Challenges — rankings, time-bound competitions
7. Activity Feed — social feed with kudos & comments

**Key architecture:**
- Dual storage: CloudKit (personal) + Supabase (social)
- Watch app unchanged (iPhone is gateway)
- Privacy-first: only sanitized workout summaries shared
- ~40 new iOS-only files, no shared model changes
- Subscription tiers defined (free social participation, Pro for power features)

**Why:** To justify subscription pricing and match competitor features (95%+ of fitness apps have leaderboards, 90%+ have challenges, 80%+ have activity feeds)

**How to apply:** Reference this plan when implementing social features. Start with Phase 1 (networking layer) before any social UI work.
