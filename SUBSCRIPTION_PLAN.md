# Subscription Plan (Deferred)

This note captures monetization decisions discussed and intentionally deferred, so work can resume later without re-planning.

## Status

- Decision: **Table paywall implementation for now**.
- Product direction: **Freemium** with meaningful free utility and clear premium value.

## Agreed Strategy

- Keep core trust/use features free:
  - Manual + NFC logging
  - Baseline reminders
  - Backup/restore
  - Privacy lock (PIN/biometrics)
- Use premium for scale + power workflows:
  - Unlimited compounds
  - Protocol/stacks management
  - Advanced analytics (30/90d, deeper insights)
  - Export/reporting (CSV/PDF)

## Candidate Free vs Premium Split

### Free

- Up to **3 active compounds**
- Dashboard + history basics
- Basic analytics (14d)
- Core reminder behavior

### Premium

- Unlimited active compounds
- Protocol creation/editing
- Advanced analytics views and cards
- CSV/PDF exports

## Feature Flag Map (for later)

- `isPremium`
- `maxActiveCompounds` (free=3, premium=unlimited)
- `canUseProtocols`
- `canUseAdvancedAnalytics`
- `canExport`
- `canUseAdvancedReminders` (optional later phase)

## Recommended Rollout

1. **Phase 1**
   - Enforce 3 active-compound cap
   - Gate protocol create/edit
   - Add paywall entry points
2. **Phase 2**
   - Gate advanced analytics
   - Gate CSV/PDF exports
3. **Phase 3**
   - Trial/copy optimization and conversion tuning

## Key UX Triggers

- Attempt to add 4th active compound
- Tap locked analytics ranges/features
- Tap protocol create/edit entry points
- Tap export actions in Settings

## Pricing Direction (tentative)

- Monthly: **$4.99**
- Annual: **$39.99**
- Trial: 7 days (triggered from high-intent actions)

## Resume Prompt

When ready to continue, use:

> Resume subscription plan from `SUBSCRIPTION_PLAN.md` and implement Phase 1 with a stubbed `SubscriptionService`.

