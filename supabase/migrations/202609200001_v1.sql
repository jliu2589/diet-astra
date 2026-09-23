begin;
create table public.astra_profiles (
 user_id uuid primary key references auth.users(id) on delete cascade,
 name text not null default '' check (length(name) <= 100)
);
create table public.astra_goals (
 user_id uuid primary key references auth.users(id) on delete cascade,
 target_weight double precision not null check (target_weight between 40 and 1000),
 calories integer not null check (calories between 800 and 10000),
 protein integer not null check (protein between 1 and 1000),
 carbs integer not null check (carbs between 1 and 1000),
 fat integer not null check (fat between 1 and 1000),
 workouts integer not null check (workouts between 0 and 14),
 weekly_rate double precision not null check (weekly_rate between -2 and 2)
);
create table public.astra_weights (
 id uuid primary key, user_id uuid not null references auth.users(id) on delete cascade,
 measured_at timestamptz not null, pounds double precision not null check (pounds between 1 and 1500)
);
create function public.astra_valid_foods(items jsonb) returns boolean language plpgsql immutable set search_path = '' as $$
declare item jsonb; field text;
begin
 if jsonb_typeof(items) is distinct from 'array' or jsonb_array_length(items) not between 1 and 50 then return false; end if;
 for item in select * from jsonb_array_elements(items) loop
  if jsonb_typeof(item->'name') is distinct from 'string' or length(trim(item->>'name')) not between 1 and 200 then return false; end if;
  perform (item->>'id')::uuid;
  if jsonb_typeof(item->'id') is distinct from 'string' or jsonb_typeof(item->'source') is distinct from 'string' or length(item->>'source') > 300 then return false; end if;
  if jsonb_typeof(item->'grams') is distinct from 'number' or (item->>'grams') is null or (item->>'grams')::numeric not between 0.001 and 10000 then return false; end if;
  foreach field in array array['calories','protein','carbs','fat'] loop
   if jsonb_typeof(item->field) is distinct from 'number' or (item->field) is null or (item->>field)::numeric not between 0 and 20000 then return false; end if;
  end loop;
 end loop;
 return true;
exception when others then return false;
end; $$;
create table public.astra_meals (
 id uuid primary key, user_id uuid not null references auth.users(id) on delete cascade,
 day date not null, occurred_at timestamptz not null,
 title text not null check (length(trim(title)) between 1 and 200),
 note text not null default '' check (length(note) <= 4000),
 foods jsonb not null check (public.astra_valid_foods(foods)), estimated boolean not null default true
);
create table public.astra_nutrition_days (
 user_id uuid not null references auth.users(id) on delete cascade, day date not null,
 complete boolean not null default false, primary key(user_id,day)
);
create function public.astra_valid_exercises(items jsonb) returns boolean language plpgsql immutable set search_path = '' as $$
declare exercise jsonb; s jsonb;
begin
 if jsonb_typeof(items) is distinct from 'array' or jsonb_array_length(items) not between 1 and 30 then return false; end if;
 for exercise in select * from jsonb_array_elements(items) loop
  perform (exercise->>'id')::uuid;
  if jsonb_typeof(exercise->'id') is distinct from 'string' or jsonb_typeof(exercise->'name') is distinct from 'string' then return false; end if;
  if (exercise->>'name') is null or length(trim(exercise->>'name')) not between 1 and 100 then return false; end if;
  if jsonb_typeof(exercise->'sets') is distinct from 'array' or jsonb_array_length(exercise->'sets') not between 1 and 30 then return false; end if;
  for s in select * from jsonb_array_elements(exercise->'sets') loop
   perform (s->>'id')::uuid;
   if jsonb_typeof(s->'id') is distinct from 'string' or jsonb_typeof(s->'reps') is distinct from 'number' or jsonb_typeof(s->'pounds') is distinct from 'number' or jsonb_typeof(s->'rir') is distinct from 'number' then return false; end if;
   if (s->>'reps') is null or (s->>'reps')::integer not between 1 and 100 or
      (s->>'pounds') is null or (s->>'pounds')::numeric not between 0 and 2000 or
      (s->>'rir') is null or (s->>'rir')::integer not between 0 and 10 then return false; end if;
  end loop;
 end loop;
 return true;
exception when others then return false;
end; $$;
create table public.astra_workouts (
 id uuid primary key, user_id uuid not null references auth.users(id) on delete cascade,
 day date not null, title text not null check (length(trim(title)) between 1 and 200),
 exercises jsonb not null check (public.astra_valid_exercises(exercises))
);
do $$ declare t text; begin
 foreach t in array array['astra_profiles','astra_goals','astra_weights','astra_meals','astra_nutrition_days','astra_workouts'] loop
  execute format('alter table public.%I enable row level security',t);
  execute format('revoke all on public.%I from anon, authenticated',t);
  execute format('grant select, insert, update, delete on public.%I to authenticated',t);
  execute format('create policy own_records on public.%I for all to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id)',t);
 end loop;
end $$;
-- Editing food invalidates an earlier completeness confirmation on either affected day.
create function public.astra_reopen_food_day() returns trigger language plpgsql set search_path = '' as $$
begin
 if TG_OP <> 'INSERT' then
  update public.astra_nutrition_days set complete=false where user_id=OLD.user_id and day=OLD.day;
 end if;
 if TG_OP <> 'DELETE' then
  update public.astra_nutrition_days set complete=false where user_id=NEW.user_id and day=NEW.day;
 end if;
 return null;
end $$;
create trigger reopen_food_day after insert or update or delete on public.astra_meals for each row execute function public.astra_reopen_food_day();
create index on public.astra_weights(user_id,measured_at);
create index on public.astra_meals(user_id,day);
create index on public.astra_workouts(user_id,day);
-- No request contents or photos are stored in this rate-limit table.
create table public.astra_ai_usage (user_id uuid references auth.users(id) on delete cascade, day date, requests integer not null, primary key(user_id,day));
alter table public.astra_ai_usage enable row level security;
revoke all on public.astra_ai_usage from anon, authenticated;
create function public.astra_claim_ai_request() returns boolean language plpgsql security definer set search_path = '' as $$
declare total integer;
begin
 if auth.uid() is null then return false; end if;
 insert into public.astra_ai_usage(user_id,day,requests) values (auth.uid(),(now() at time zone 'UTC')::date,1)
 on conflict(user_id,day) do update set requests=public.astra_ai_usage.requests+1 where public.astra_ai_usage.requests < 60
 returning requests into total;
 return total is not null;
end $$;
revoke all on function public.astra_claim_ai_request() from public, anon;
grant execute on function public.astra_claim_ai_request() to authenticated;
commit;
