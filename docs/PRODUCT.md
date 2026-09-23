# Product

Diet Astra is a private iPhone app for daily nutrition, weight trends and strength
training. Accounts are independent; the intended first users are the owner and
mother, with no hard-coded identities or shared health records.

## V1 scope

- Authenticated daily dashboard and historical day/week/month review.
- Manual weight history, edit/delete, trend/rate; read-only HealthKit weight,
  steps, workout details, active energy and exercise minutes with explicit permission.
- Structured meal foods/portions and editable calories, protein, carbs and fat.
- Typed or native on-device dictated input; camera/library photos plus context;
  server-side AI interpretation followed by mandatory review and explicit save.
- Per-user nutrition/weight/training goals, deterministic projections, and a
  conservative maintenance estimate after sufficient complete records exist.
- Strength sessions, exercises, sets, reps, pounds, RIR, history and previous sets.
- Real-data weight/calorie/protein/training charts and goal comparisons.

## Data rules

AI estimates are not nutrition truth. Users can enter label/measured values,
correct every estimated food and portion, and identify whether a meal includes
estimates. V1 has no verified food database: AI-derived per-100g values are clearly
estimated, portion scaling and totals are deterministic. A verified nutrition
source remains a future accuracy improvement, not a claimed V1 capability.

HealthKit is read only and stays on device; manual measurements take precedence
on days with manual entries. No automatic upload or duplication of Health data.
Photo analysis is explicit; Astra discards images when the composer closes and
stores confirmed nutrition only. The former demo photo gallery is intentionally
absent from authenticated accounts under the V1 no-permanent-photo-storage rule.

Missing food logs are not zero-intake days. Users mark a food day complete; any
meal change reopens it. Maintenance estimation requires complete intake history.
The app does not recommend medical treatment or automatically alter calorie goals.

## Status and boundaries

Implementation and local checks do not establish a working deployed V1. See
[V1 acceptance](V1.md) for verified results and remaining Supabase/device steps.
Prototype fixtures are Debug-only navigation and never appear as account data.

Apple Watch UI, AI coaching, social features, complex recommendations, automation,
and direct VeSync integration remain out of scope. No offline mutation queue is
provided: failed saves retain their draft and require retry.
