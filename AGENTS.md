# Diet Astra

Diet Astra is a native iOS diet, fitness, and long-term health tracking application.

## Stack
- Swift
- SwiftUI
- HealthKit
- Apple Watch integration later
- Supabase / PostgreSQL
- OpenAI API
- GitHub for source control

## Product Goals
- Track body weight and long-term weight trends.
- Import weight and activity data through Apple Health when possible.
- Support meal logging by text, dictation, and photo.
- Convert meal input into structured foods, quantities, calories, protein, carbohydrates, fat, and other nutrition data.
- Estimate maintenance calories from observed calorie intake and weight trends.
- Support weight goals and projections.
- Track strength workouts including exercises, sets, reps, weight, and RIR/intensity.
- Eventually support an Apple Watch workout experience.

## Development Principles
- Build the smallest usable vertical slice before adding advanced features.
- Keep deterministic calculations in code rather than relying on an LLM.
- Use AI primarily for understanding unstructured input, reasoning, and assistance.
- Treat HealthKit as the main Apple health/device integration layer.
- Keep health information private and minimize unnecessary data collection.
- Separate MVP features from future features.
- Preserve important architecture and product decisions.
- Prefer simple architecture until complexity is justified.
- When proposing implementation work, give concrete next steps.
- When changing architecture, explain why.
- Treat the GitHub repository and application code as the source of truth for implementation.

## Coding Rules
- Keep SwiftUI views small and composable.
- Prefer clear, boring architecture over premature abstractions.
- Avoid introducing new dependencies unless they solve a real problem.
- Keep business logic out of views when practical.
- Add comments only when they explain non-obvious reasoning.
- Do not silently change established architecture.
- Run/build/test the app before considering implementation work complete.
- Record important architectural decisions in the repository.

## MVP Scope
Focus first on:
1. Weight tracking.
2. Text-based meal logging.
3. Daily calorie and macro totals.
4. Weight goals and projections.
5. Basic strength workout logging.

Defer until later unless explicitly requested:
- Apple Watch workout UI.
- Advanced AI coaching.
- Social features.
- Complex recommendation systems.
- Sophisticated automation/orchestration.
- Direct VeSync integrations if HealthKit can provide the data.

## AI / Nutrition Rules
- Use AI to interpret unstructured meal input, not as the sole source of nutrition truth.
- Prefer structured output from the OpenAI API.
- Keep calorie, macro, goal, and projection calculations deterministic in code.
- Make AI-generated meal estimates editable before saving.
- Clearly distinguish measured data from estimated data.

## HealthKit Rules
- Request only the HealthKit permissions the current feature needs.
- Prefer Apple Health as the integration layer for device-derived health data.
- Avoid unnecessary duplication of HealthKit data in the backend.
- Treat health data as sensitive and minimize storage and exposure.

## Working Style for Codex
Before significant work:
1. Read this file.
2. Inspect the relevant project files.
3. Understand the current architecture before modifying it.
4. Prefer extending the existing structure over replacing it.

When finishing work:
1. Make sure the project builds.
2. Run relevant tests if available.
3. Summarize what changed.
4. Call out unresolved issues or tradeoffs.
5. Suggest the smallest logical next step.
