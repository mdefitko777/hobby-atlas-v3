-- Hobby Atlas v3 — 기기에만 있던 기록을 계정에 (다른 기기 · 다시 설치해도 그대로)
--
-- 순서 (Supabase → SQL Editor, 파일 전체를 붙여 넣고 Run):
--   1) Gunpula 저장소 docs/supabase-setup-v3.sql · supabase-v3-fix-grants.sql
--   2) 이 저장소 docs/supabase-v3-photos.sql → docs/supabase-v3-social.sql
--   3) 이 파일 docs/supabase-v3-sync.sql
-- 여러 번 돌려도 된다 (if not exists · or replace).
--
-- 만드는 것
--   1. 표 gunpula_v3_device_state — 계정마다 한 줄: data(jsonb) + revision. 직접 읽기 · 쓰기 막고 RPC 로만
--      data 에 들어가는 것 (앱이 정한다, 서버는 모양을 보지 않는다):
--        베이 부품 · 베이 연결 · 베이 조합 · 덱 · 도감 손으로 켜기 · 메자스타 · 프렌다 태그 · 특별 관심 친구 · 내 채널 …
--      옛 Gunpula 앱과 같이 쓰는 payload(gunpula_v3_users.payload) 에는 넣지 않는다 — 옛 앱이 모르는 키를 지울 수 있어서.
--   2. RPC gunpula_v3_get_device_state() · gunpula_v3_save_device_state(p_data, p_base_revision)
--      저장은 낙관적 잠금: p_base_revision 이 지금 revision 과 다르면 40001 → 앱이 다시 받아 합친 뒤 재시도
--   3. RPC gunpula_v3_get_my_photos() — 다시 설치했을 때 내 사진 목록을 되찾는다 (파일은 Storage photos/<uid>/…)

-- ---------------------------------------------------------------------------
-- 1. 표
-- ---------------------------------------------------------------------------

create table if not exists public.gunpula_v3_device_state (
  user_id uuid primary key references auth.users(id) on delete cascade,
  data jsonb not null default '{}'::jsonb,
  revision bigint not null default 0,
  updated_at timestamptz not null default now()
);

alter table public.gunpula_v3_device_state enable row level security;
revoke all on public.gunpula_v3_device_state from anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. RPC — 기기 기록
-- ---------------------------------------------------------------------------

create or replace function public.gunpula_v3_get_device_state()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  row_data jsonb;
  row_rev bigint;
  row_at timestamptz;
begin
  perform public.gunpula_v3_ensure_self();
  select s.data, s.revision, s.updated_at into row_data, row_rev, row_at
    from public.gunpula_v3_device_state s where s.user_id = auth.uid();
  return jsonb_build_object(
    'data', coalesce(row_data, '{}'::jsonb),
    'revision', coalesce(row_rev, 0),
    'updated_at', row_at
  );
end;
$$;

-- p_base_revision = 앱이 마지막으로 받은 revision. 다르면 40001 (다른 기기가 먼저 썼다)
create or replace function public.gunpula_v3_save_device_state(p_data jsonb, p_base_revision bigint)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  cur bigint;
begin
  perform public.gunpula_v3_ensure_self();
  if p_data is null or jsonb_typeof(p_data) <> 'object' then
    raise exception 'gunpula bad device state' using errcode = '22023';
  end if;
  if pg_column_size(p_data) > 1048576 then
    raise exception 'gunpula device state too large' using errcode = '54000';
  end if;

  insert into public.gunpula_v3_device_state (user_id) values (auth.uid())
  on conflict (user_id) do nothing;

  select s.revision into cur from public.gunpula_v3_device_state s
   where s.user_id = auth.uid() for update;
  if cur <> coalesce(p_base_revision, 0) then
    raise exception 'gunpula device state changed' using errcode = '40001';
  end if;

  update public.gunpula_v3_device_state
     set data = p_data, revision = cur + 1, updated_at = now()
   where user_id = auth.uid();

  return jsonb_build_object('revision', cur + 1, 'updated_at', now());
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. RPC — 내 사진 목록 (다시 설치 · 다른 기기)
-- ---------------------------------------------------------------------------

create or replace function public.gunpula_v3_get_my_photos()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  photos jsonb;
begin
  perform public.gunpula_v3_ensure_self();
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', p.photo_id,
           'path', p.user_id::text || '/' || p.photo_id || '.jpg',
           'kit_id', p.kit_id,
           'unit_id', p.unit_id,
           'watermark', p.watermark,
           'created_at', p.created_at
         ) order by p.created_at desc), '[]'::jsonb)
    into photos
    from public.gunpula_v3_photos p
   where p.user_id = auth.uid();
  return photos;
end;
$$;

revoke all on function public.gunpula_v3_get_device_state() from public, anon, authenticated;
revoke all on function public.gunpula_v3_save_device_state(jsonb, bigint) from public, anon, authenticated;
revoke all on function public.gunpula_v3_get_my_photos() from public, anon, authenticated;
grant execute on function public.gunpula_v3_get_device_state() to authenticated;
grant execute on function public.gunpula_v3_save_device_state(jsonb, bigint) to authenticated;
grant execute on function public.gunpula_v3_get_my_photos() to authenticated;

-- PostgREST 가 새 함수를 바로 보게
notify pgrst, 'reload schema';
