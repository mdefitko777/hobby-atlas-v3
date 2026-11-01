-- Hobby Atlas v3 — 친구 쪽 2차: 아바타 · 배경 사진 / 사진 공개 범위(전체 끄기 · 친구별 숨기기) / 알 수도 있는 친구
--
-- 순서 (Supabase → SQL Editor, 파일 전체를 붙여 넣고 Run):
--   1) Gunpula 저장소 docs/supabase-setup-v3.sql · supabase-v3-fix-grants.sql   (이미 돌림)
--   2) 이 저장소 docs/supabase-v3-photos.sql                                   (photos 버킷 · 사진 벽)
--   3) 이 파일 docs/supabase-v3-social.sql
-- 여러 번 돌려도 된다 (if not exists · or replace · drop policy if exists).
-- ⚠ 2) 를 나중에 다시 돌리면 photos 버킷 읽기 정책이 옛것(친구면 다 보임)으로 돌아간다 → 그 뒤에 3) 도 다시 돌린다.
--
-- 돌리기 전 앱: 아바타 · 배경은 기기에만(첫 글자 아바타로 대신), 공개 범위는 기기에만 + 사진 벽 ⚠
--   (전체 끄기는 앱이 올린 사진을 Storage 에서 내려서 지킨다. 친구별 숨기기는 이 SQL 이 있어야 지켜진다),
--   알 수도 있는 친구 칸은 숨김.
--
-- 만드는 것
--   1. 표 gunpula_v3_photo_privacy (내 사진 공개 on/off) · gunpula_v3_photo_hidden (내 사진을 못 보는 친구)
--      — 직접 읽기 · 쓰기 막음, RPC 로만
--   2. photos 버킷 읽기 정책 바꿈: 자기 것 = 다 / 친구 = 프로필 사진(<uid>/profile/…)은 늘, 나머지 사진은
--      주인이 공개를 켰고 나를 숨기지 않았을 때만. 쓰기 · 지우기 정책(자기 폴더만)은 photos SQL 그대로라
--      <uid>/profile/avatar.jpg · cover.jpg 도 이미 올릴 수 있다.
--   3. gunpula_v3_get_friend_wall 다시 정의: 공개 범위를 지키고, 친구의 아바타 · 배경 경로를 같이 준다
--   4. RPC gunpula_v3_get_photo_privacy · gunpula_v3_set_photo_privacy · gunpula_v3_suggest_friends
--
-- 아바타 · 배경 경로는 이미 있는 gunpula_v3_users.preferences 에 둔다 (새 열 없음):
--   preferences.avatar = '<uid>/profile/avatar.jpg', preferences.avatar_at = 고른 시각(ISO) — cover 도 같은 모양.
--   앱은 기존 gunpula_v3_update_profile(p_preferences) 로 쓴다 (preferences 통째로 바뀌므로 앱이 합쳐서 보냄).
--   users.avatar 열(옛 앱이 data URL 을 넣을 수 있음)은 건드리지 않는다.

-- ---------------------------------------------------------------------------
-- 1. 표
-- ---------------------------------------------------------------------------

create table if not exists public.gunpula_v3_photo_privacy (
  user_id uuid primary key references auth.users(id) on delete cascade,
  photos_public boolean not null default true,
  updated_at timestamptz not null default now()
);

create table if not exists public.gunpula_v3_photo_hidden (
  owner_id uuid not null references auth.users(id) on delete cascade,
  viewer_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (owner_id, viewer_id),
  constraint gunpula_v3_photo_hidden_not_self check (owner_id <> viewer_id)
);

alter table public.gunpula_v3_photo_privacy enable row level security;
alter table public.gunpula_v3_photo_hidden enable row level security;
revoke all on public.gunpula_v3_photo_privacy from anon, authenticated;
revoke all on public.gunpula_v3_photo_hidden from anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. 도우미 + Storage 읽기 정책
-- ---------------------------------------------------------------------------

-- p_viewer 가 p_owner 의 사진 벽(프로필 사진 말고)을 볼 수 있나 — 내부용 (EXECUTE 없음)
create or replace function public.gunpula_v3_photos_visible(p_owner uuid, p_viewer uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select p_owner is not null and p_viewer is not null and (
    p_owner = p_viewer
    or (
      public.gunpula_v3_are_friends(p_owner, p_viewer)
      and coalesce((select pp.photos_public from public.gunpula_v3_photo_privacy pp where pp.user_id = p_owner), true)
      and not exists (
        select 1 from public.gunpula_v3_photo_hidden h where h.owner_id = p_owner and h.viewer_id = p_viewer
      )
    )
  );
$$;

-- storage.objects 정책 안에서 부르므로 authenticated 에게 EXECUTE 가 있어야 한다.
-- 답은 "지금 사람이 이 파일을 읽어도 되나" 뿐이라 남의 설정이 새지 않는다.
create or replace function public.gunpula_v3_can_read_photo_object(p_name text)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  owner_text text := split_part(coalesce(p_name, ''), '/', 1);
  owner_id uuid;
begin
  if auth.uid() is null or owner_text = '' then
    return false;
  end if;
  if owner_text = auth.uid()::text then
    return true;
  end if;
  if owner_text !~ '^[0-9a-fA-F-]{36}$' then
    return false;
  end if;
  owner_id := owner_text::uuid;
  if not public.gunpula_v3_are_friends(owner_id, auth.uid()) then
    return false;
  end if;
  -- 아바타 · 배경은 친구 모두에게
  if p_name like owner_text || '/profile/%' then
    return true;
  end if;
  return public.gunpula_v3_photos_visible(owner_id, auth.uid());
end;
$$;

revoke all on function public.gunpula_v3_photos_visible(uuid, uuid) from public, anon, authenticated;
revoke all on function public.gunpula_v3_can_read_photo_object(text) from public, anon, authenticated;
grant execute on function public.gunpula_v3_can_read_photo_object(text) to authenticated;

drop policy if exists "gunpula_v3_photos_read" on storage.objects;
create policy "gunpula_v3_photos_read" on storage.objects
  for select to authenticated
  using (bucket_id = 'photos' and public.gunpula_v3_can_read_photo_object(name));

-- ---------------------------------------------------------------------------
-- 3. 친구 사진 벽 (photos SQL 의 것을 바꿔 씀) — 공개 범위 + 아바타 · 배경 경로
-- ---------------------------------------------------------------------------

create or replace function public.gunpula_v3_get_friend_wall(p_handle text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  target public.gunpula_v3_users%rowtype;
  photos jsonb := '[]'::jsonb;
  prefix text;
  avatar_path text;
  cover_path text;
begin
  perform public.gunpula_v3_ensure_self();
  select * into target from public.gunpula_v3_users
   where handle = public.gunpula_v3_norm_handle(p_handle);
  if not found then
    raise exception 'gunpula user not found' using errcode = '22023';
  end if;
  if not public.gunpula_v3_are_friends(auth.uid(), target.user_id) then
    raise exception 'gunpula not friends' using errcode = '42501';
  end if;

  -- 숨겨졌으면 빈 벽 (숨겼다는 사실은 알리지 않는다)
  if public.gunpula_v3_photos_visible(target.user_id, auth.uid()) then
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
     where p.user_id = target.user_id;
  end if;

  -- preferences 의 경로는 그 사람 폴더 안 profile/ 일 때만 믿는다
  prefix := target.user_id::text || '/profile/';
  avatar_path := case when coalesce(target.preferences ->> 'avatar', '') like prefix || '%'
                      then target.preferences ->> 'avatar' else '' end;
  cover_path := case when coalesce(target.preferences ->> 'cover', '') like prefix || '%'
                     then target.preferences ->> 'cover' else '' end;

  return public.gunpula_v3_public_profile(target.user_id) || jsonb_build_object(
    'photos', photos,
    'tags', case when jsonb_typeof(target.preferences -> 'tags') = 'array'
                 then target.preferences -> 'tags' else '[]'::jsonb end,
    'avatar_path', avatar_path,
    'avatar_at', case when avatar_path = '' then '' else coalesce(target.preferences ->> 'avatar_at', '') end,
    'cover_path', cover_path,
    'cover_at', case when cover_path = '' then '' else coalesce(target.preferences ->> 'cover_at', '') end
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. 공개 범위 RPC
-- ---------------------------------------------------------------------------

create or replace function public.gunpula_v3_get_photo_privacy()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  pub boolean;
  hidden jsonb;
begin
  perform public.gunpula_v3_ensure_self();
  select coalesce((select pp.photos_public from public.gunpula_v3_photo_privacy pp where pp.user_id = auth.uid()), true)
    into pub;
  select coalesce(jsonb_agg(u.handle order by u.handle), '[]'::jsonb)
    into hidden
    from public.gunpula_v3_photo_hidden h
    join public.gunpula_v3_users u on u.user_id = h.viewer_id
   where h.owner_id = auth.uid() and u.handle is not null;
  return jsonb_build_object('public', pub, 'hidden', hidden);
end;
$$;

-- 통째로 바꾼다: p_public = 사진 공개, p_hidden = 내 사진을 못 볼 @아이디 목록 (없는 아이디는 무시)
create or replace function public.gunpula_v3_set_photo_privacy(p_public boolean, p_hidden text[] default '{}')
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.gunpula_v3_ensure_self();
  if coalesce(array_length(p_hidden, 1), 0) > 500 then
    raise exception 'gunpula too many hidden friends' using errcode = '54000';
  end if;
  insert into public.gunpula_v3_photo_privacy (user_id, photos_public, updated_at)
  values (auth.uid(), coalesce(p_public, true), now())
  on conflict (user_id) do update set photos_public = excluded.photos_public, updated_at = now();

  delete from public.gunpula_v3_photo_hidden where owner_id = auth.uid();
  insert into public.gunpula_v3_photo_hidden (owner_id, viewer_id)
  select distinct auth.uid(), u.user_id
    from unnest(coalesce(p_hidden, '{}'::text[])) as h(handle)
    join public.gunpula_v3_users u on u.handle = public.gunpula_v3_norm_handle(h.handle)
   where u.user_id <> auth.uid()
  on conflict do nothing;

  return public.gunpula_v3_get_photo_privacy();
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. 알 수도 있는 친구 = 친구의 친구 (이미 친구 · 요청 중인 사람 · 나 제외) + 함께 아는 친구 수
-- ---------------------------------------------------------------------------

create or replace function public.gunpula_v3_suggest_friends(p_limit int default 20)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid;
  result jsonb;
begin
  perform public.gunpula_v3_ensure_self();
  me := auth.uid();
  with mine as (
    select case when f.requester_id = me then f.addressee_id else f.requester_id end as fid
      from public.gunpula_v3_friendships f
     where f.status = 'accepted' and (f.requester_id = me or f.addressee_id = me)
  ), fof as (
    select case when f.requester_id = m.fid then f.addressee_id else f.requester_id end as cand, m.fid
      from public.gunpula_v3_friendships f
      join mine m on (f.requester_id = m.fid or f.addressee_id = m.fid)
     where f.status = 'accepted'
  ), cand as (
    select o.cand, count(distinct o.fid) as mutual
      from fof o
     where o.cand <> me
       and not exists (
         select 1 from public.gunpula_v3_friendships x
          where (x.requester_id = me and x.addressee_id = o.cand)
             or (x.addressee_id = me and x.requester_id = o.cand)
       )
     group by o.cand
  ), top as (
    select c.cand, c.mutual
      from cand c
      join public.gunpula_v3_users u on u.user_id = c.cand
     where u.handle is not null
     order by c.mutual desc, u.handle
     limit greatest(1, least(coalesce(p_limit, 20), 50))
  )
  select coalesce(jsonb_agg(public.gunpula_v3_public_profile(t.cand) || jsonb_build_object('mutual', t.mutual)
                            order by t.mutual desc), '[]'::jsonb)
    into result
    from top t;
  return result;
end;
$$;

revoke all on function public.gunpula_v3_get_friend_wall(text) from public, anon, authenticated;
revoke all on function public.gunpula_v3_get_photo_privacy() from public, anon, authenticated;
revoke all on function public.gunpula_v3_set_photo_privacy(boolean, text[]) from public, anon, authenticated;
revoke all on function public.gunpula_v3_suggest_friends(int) from public, anon, authenticated;
grant execute on function public.gunpula_v3_get_friend_wall(text) to authenticated;
grant execute on function public.gunpula_v3_get_photo_privacy() to authenticated;
grant execute on function public.gunpula_v3_set_photo_privacy(boolean, text[]) to authenticated;
grant execute on function public.gunpula_v3_suggest_friends(int) to authenticated;

-- PostgREST 가 새 함수를 바로 보게
notify pgrst, 'reload schema';
