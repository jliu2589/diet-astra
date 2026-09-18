# Product

Diet Astra helps users track diet, strength training, body weight, and long-term
health. The current bootstrap provides navigation and placeholders only.

## MVP priorities

1. Record body weight and show long-term trends.
2. Log meals from text as structured foods, quantities, calories, and macros.
3. Show daily calorie and macro totals.
4. Support weight goals and projections; estimate maintenance calories from
   observed intake and weight trends.
5. Log strength exercises, sets, reps, weight, and RIR/intensity.

## Later

Import weight and activity through HealthKit, add meal dictation and photos,
and eventually support Apple Watch workouts. Advanced AI coaching, social
features, complex recommendations, sophisticated automation, and direct VeSync
integration are outside the MVP. Prefer HealthKit when device data is available there.

## Data and nutrition principles

- Keep calorie, macro, goal, and projection calculations deterministic in code.
- Use AI to interpret unstructured input, with structured output; it must not
  be the sole source of nutrition truth.
- Let users edit AI meal estimates before saving and distinguish estimates
  from measured data.
- Minimize collection and storage of sensitive health information. Request only
  HealthKit permissions required by the feature and avoid unnecessary backend duplication.

Future integrations may use HealthKit, Supabase/PostgreSQL, and the OpenAI API.
None are part of this bootstrap.
