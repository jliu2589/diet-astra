\set ON_ERROR_STOP on
-- Run only in an isolated disposable PostgreSQL database, not a live project.
create schema auth;
create role anon;
create role authenticated;
create table auth.users(id uuid primary key);
create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub', true),'')::uuid $$;
grant usage on schema auth, public to authenticated, anon;
grant execute on function auth.uid() to authenticated, anon;
\ir ../supabase/migrations/202609200001_v1.sql
insert into auth.users values ('11111111-1111-4111-8111-111111111111'),('22222222-2222-4222-8222-222222222222');
create function public.check_astra(condition boolean, message text) returns void language plpgsql as $$ begin if condition is distinct from true then raise exception '%', message; end if; end $$;
-- Valid fixtures for both owners. UUID fixtures are disposable test identities.
insert into astra_profiles select id,'Test' from auth.users;
insert into astra_goals select id,150,2000,120,250,65,3,-0.5 from auth.users;
insert into astra_weights select id,id,now(),160 from auth.users;
insert into astra_meals select id,id,current_date,now(),'Lunch','', '[{"id":"33333333-3333-4333-8333-333333333333","name":"Rice","grams":100,"calories":130,"protein":3,"carbs":28,"fat":0.3,"source":"Manual"}]',false from auth.users;
insert into astra_nutrition_days select id,current_date,true from auth.users;
insert into astra_workouts select id,id,current_date,'Strength','[{"id":"33333333-3333-4333-8333-333333333333","name":"Squat","sets":[{"id":"44444444-4444-4444-8444-444444444444","reps":5,"pounds":100,"rir":2}]}]' from auth.users;
set role authenticated;
set request.jwt.claim.sub='11111111-1111-4111-8111-111111111111';
do $$ declare t text; n int; begin
 foreach t in array array['astra_profiles','astra_goals','astra_weights','astra_meals','astra_nutrition_days','astra_workouts'] loop
  execute format('select count(*) from %I',t) into n;
  perform public.check_astra(n=1, t||' exposes another user');
  execute format('update %I set user_id=user_id where user_id=%L',t,'22222222-2222-4222-8222-222222222222');
  get diagnostics n = row_count;
  perform public.check_astra(n=0,t||' allows cross-user update');
  execute format('delete from %I where user_id=%L',t,'22222222-2222-4222-8222-222222222222');
  get diagnostics n = row_count;
  perform public.check_astra(n=0,t||' allows cross-user delete');
  begin
   execute format('update %I set user_id=%L where user_id=auth.uid()',t,'22222222-2222-4222-8222-222222222222');
   raise exception '% permits transferring ownership',t;
  exception when insufficient_privilege then null; end;
 end loop;
 begin
  insert into astra_weights values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','22222222-2222-4222-8222-222222222222',now(),150);
  raise exception 'Cross-owner insert accepted';
 exception when insufficient_privilege then null; end;
end $$;
update astra_meals set title='Updated lunch' where user_id=auth.uid();
select check_astra((select complete from astra_nutrition_days where user_id=auth.uid())=false,'Meal edit must reopen complete day');
-- Idempotent own save, update and delete.
insert into astra_weights values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',auth.uid(),now(),150);
insert into astra_weights values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',auth.uid(),now(),151) on conflict(id) do update set pounds=excluded.pounds;
select check_astra((select pounds from astra_weights where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')=151,'Own upsert');
delete from astra_weights where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
do $$ begin
 for i in 1..60 loop perform public.check_astra(astra_claim_ai_request(),'Quota failed too early'); end loop;
 perform public.check_astra(not astra_claim_ai_request(),'Quota not enforced');
 begin perform * from astra_ai_usage; raise exception 'Usage table accessible'; exception when insufficient_privilege then null; end;
end $$;
set request.jwt.claim.sub='22222222-2222-4222-8222-222222222222';
select check_astra((select count(*) from astra_weights)=1,'B isolation');
select check_astra(astra_claim_ai_request(),'B quota not independent');
set role anon;
do $$ begin
 begin perform * from astra_weights; raise exception 'Anonymous access'; exception when insufficient_privilege then null; end;
 begin perform astra_claim_ai_request(); raise exception 'Anonymous quota RPC'; exception when insufficient_privilege then null; end;
end $$;
reset role;
select check_astra(not astra_valid_foods('[{}]'),'Empty food accepted');
select check_astra(not astra_valid_exercises('[{"name":"Squat"}]'),'Missing sets accepted');
select check_astra(not astra_valid_foods('null'),'Null food accepted');
select check_astra((select count(*) from pg_class where relname like 'astra_%' and relkind='r' and relrowsecurity)=7,'All seven tables require RLS');
select 'RLS checks passed: isolation, read/update/delete, ownership change, own upsert/delete, anonymous denial, per-user quota, constraints' as result;
