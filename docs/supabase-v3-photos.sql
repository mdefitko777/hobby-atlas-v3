-- Hobby Atlas v3 — 사진 벽 공유 (Supabase Storage) + 취향 태그
--
-- 먼저 돌려 둔 것: Gunpula 저장소 docs/supabase-setup-v3.sql · supabase-v3-fix-grants.sql
-- (gunpula_v3_users · gunpula_v3_friendships · gunpula_v3_ensure_self · gunpula_v3_public_profile ·
--  gunpula_v3_are_friends · gunpula_v3_norm_handle 를 그대로 쓴다)
--
-- Supabase → SQL Editor 에 이 파일 전체를 붙여 넣고 한 번 Run. 여러 번 돌려도 된다 (if not exists · or replace).
-- 돌리기 전에는 앱이 사진을 기기에만 두고 내 정보 사진 벽 머리에 ⚠ 하나만 보인다 (고장 나지 않음).
--
-- 만드는 것
--   1. Storage 버킷 `photos` (비공개 · 5 MB · jpeg/png/webp). 경로 = `<user_id>/<photo_id>.jpg`
--   2. storage.objects RLS: 쓰기 · 바꾸기 · 지우기 = 자기 폴더만, 읽기 = 자기 + 수락한 친구
--   3. 표 gunpula_v3_photos (어떤 사진이 친구에게 보이는지 목록) — 직접 읽기 · 쓰기는 막고 RPC 로만
--   4. RPC: gunpula_v3_put_photo · gunpula_v3_delete_photo · gunpula_v3_get_friend_wall
--   5. 취향 태그 = 이미 있는 gunpula_v3_users.preferences 의 tags (새 열 없음).
--      내 것은 기존 gunpula_v3_update_profile(p_preferences) 로 쓰고, 친구 것은 get_friend_wall 이 tags 만 꺼내 준다
--      (preferences 의 다른 값은 친구에게 보이지 않는다).
--
-- 개인정보: 친구에게 보이기를 끈 사진은 앱이 Storage 에서 지우고 목록에서도 뺀다. 홈 커버 사진(payload.appearance)은 여기와 상관없다.

-- ---------------------------------------------------------------------------
-- 1. 버킷
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('photos', 'photos', false, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
  set public = false,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- ---------------------------------------------------------------------------
-- 2. 표 (목록)
-- ---------------------------------------------------------------------------

create table if not exists public.gunpula_v3_photos (
  user_id uuid not null references auth.users(id) on delete cascade,
  photo_id text not null check (photo_id ~ '^[a-z0-9_-]{4,64}$'),
  kit_id text not null default '',
  unit_id text not null default '',
  -- 저장할 때 "HA · @아이디" 워터마크를 넣을지 (올린 사람이 정한다)
  watermark boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, photo_id)
);

alter table public.gunpula_v3_photos enable row level security;
revoke all on public.gunpula_v3_photos from anon, authenticated;

-- ---------------------------------------------------------------------------
-- 3. Storage 정책 도우미 — 이 폴더(=user_id)의 사진을 지금 사람이 읽어도 되는지
-- ---------------------------------------------------------------------------
-- storage.objects 정책 안에서 부르므로 authenticated 에게 EXECUTE 가 있어야 한다.
-- 답은 "나 자신이거나 수락한 친구인가" 뿐이라 남의 정보가 새지 않는다.

create or replace function public.gunpula_v3_can_read_photos(p_owner text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select auth.uid() is not null and (
    p_owner = auth.uid()::text
    or exists (
      select 1 from public.gunpula_v3_friendships f
       where f.status = 'accepted'
         and ((f.requester_id = auth.uid() and f.addressee_id::text = p_owner)
           or (f.addressee_id = auth.uid() and f.requester_id::text = p_owner))
    )
  );
$$;

revoke all on function public.gunpula_v3_can_read_photos(text) from public, anon, authenticated;
grant execute on function public.gunpula_v3_can_read_photos(text) to authenticated;

drop policy if exists "gunpula_v3_photos_read" on storage.objects;
create policy "gunpula_v3_photos_read" on storage.objects
  for select to authenticated
  using (bucket_id = 'photos' and public.gunpula_v3_can_read_photos((storage.foldername(name))[1]));

drop policy if exists "gunpula_v3_photos_insert" on storage.objects;
create policy "gunpula_v3_photos_insert" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'photos' and (storage.foldername(name))[1] = auth.uid()::text);

-- upsert(같은 id 다시 올리기)는 update 정책도 필요하다
drop policy if exists "gunpula_v3_photos_update" on storage.objects;
create policy "gunpula_v3_photos_update" on storage.objects
  for update to authenticated
  using (bucket_id = 'photos' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'photos' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "gunpula_v3_photos_delete" on storage.objects;
create policy "gunpula_v3_photos_delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'photos' and (storage.foldername(name))[1] = auth.uid()::text);

-- ---------------------------------------------------------------------------
-- 4. RPC
-- ---------------------------------------------------------------------------

-- 사진 한 장을 "친구에게 보임"으로 등록 (앱이 Storage 에 먼저 올린 뒤 부른다). 같은 id 면 고친다.
create or replace function public.gunpula_v3_put_photo(
  p_photo_id text,
  p_kit_id text default '',
  p_unit_id text default '',
  p_watermark boolean default true,
  p_created_at timestamptz default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  n int;
begin
  perform public.gunpula_v3_ensure_self();
  if p_photo_id is null or p_photo_id !~ '^[a-z0-9_-]{4,64}$' then
    raise exception 'gunpula bad photo id' using errcode = '22023';
  end if;
  select count(*) into n from public.gunpula_v3_photos where user_id = auth.uid();
  if n >= 500 and not exists (
    select 1 from public.gunpula_v3_photos where user_id = auth.uid() and photo_id = p_photo_id
  ) then
    raise exception 'gunpula too many photos' using errcode = '54000';
  end if;
  insert into public.gunpula_v3_photos (user_id, photo_id, kit_id, unit_id, watermark, created_at, updated_at)
  values (auth.uid(), p_photo_id, left(coalesce(p_kit_id, ''), 120), left(coalesce(p_unit_id, ''), 40),
          coalesce(p_watermark, true), coalesce(p_created_at, now()), now())
  on conflict (user_id, photo_id) do update
    set kit_id = excluded.kit_id,
        unit_id = excluded.unit_id,
        watermark = excluded.watermark,
        updated_at = now();
  return jsonb_build_object('id', p_photo_id, 'path', auth.uid()::text || '/' || p_photo_id || '.jpg');
end;
$$;

-- 목록에서 빼기 (Storage 파일은 앱이 Storage API 로 지운다 — SQL 로 storage.objects 를 지우면 안 된다)
create or replace function public.gunpula_v3_delete_photo(p_photo_id text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.gunpula_v3_ensure_self();
  delete from public.gunpula_v3_photos where user_id = auth.uid() and photo_id = p_photo_id;
  return jsonb_build_object('id', p_photo_id);
end;
$$;

-- 친구의 사진 벽 + 취향 태그 (수락한 친구만). 사진 파일은 앱이 path 로 Storage 에서 받는다 (위 읽기 정책).
create or replace function public.gunpula_v3_get_friend_wall(p_handle text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  target public.gunpula_v3_users%rowtype;
  photos jsonb;
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

  return public.gunpula_v3_public_profile(target.user_id) || jsonb_build_object(
    'photos', photos,
    'tags', case when jsonb_typeof(target.preferences -> 'tags') = 'array'
                 then target.preferences -> 'tags' else '[]'::jsonb end
  );
end;
$$;

revoke all on function public.gunpula_v3_put_photo(text, text, text, boolean, timestamptz) from public, anon, authenticated;
revoke all on function public.gunpula_v3_delete_photo(text) from public, anon, authenticated;
revoke all on function public.gunpula_v3_get_friend_wall(text) from public, anon, authenticated;
grant execute on function public.gunpula_v3_put_photo(text, text, text, boolean, timestamptz) to authenticated;
grant execute on function public.gunpula_v3_delete_photo(text) to authenticated;
grant execute on function public.gunpula_v3_get_friend_wall(text) to authenticated;

-- PostgREST 가 새 함수를 바로 보게
notify pgrst, 'reload schema';
