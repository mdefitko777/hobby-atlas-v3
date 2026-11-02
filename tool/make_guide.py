"""docs/디자인가이드.md 생성 — 3장 요소표는 코드 화면 파일 맨 위 대응표에서 그대로 뽑는다(번호 · 명칭 일치 보장).

쓰는 법 (프로젝트 폴더에서):  python tool/make_guide.py .
"""
import glob
import json
import os
import re
import subprocess
import sys

root = sys.argv[1]
os.chdir(root)

# ---------------- 코드 대응표 읽기 ----------------
SCREENS = [
    ('S', '앱 셸', ['lib/screens/s_app_shell.dart', 'lib/main.dart']),
    ('C', '채널 바 · 채널 관리', ['lib/screens/c_channel_screen.dart']),
    ('A', '홈', ['lib/screens/a_home_screen.dart']),
    ('B', '검색', ['lib/screens/b_search_screen.dart']),
    ('O', '전체 목록 (홈 · 검색 안의 보기)', ['lib/screens/o_see_all_screen.dart']),
    ('D', '상품 상세', ['lib/screens/d_kit_detail_screen.dart']),
    ('E', '찍어서 찾기 (카메라 · 인식 결과 · 사진 · 공유로 찾기)', ['lib/screens/e_camera_screen.dart', 'lib/screens/e_photo_find_screen.dart']),
    ('H', '캘린더', ['lib/screens/h_calendar_screen.dart']),
    ('F', '컬렉션', ['lib/screens/f_collection_screen.dart']),
    ('G', '도감 (컬렉션의 다른 보기)', ['lib/screens/g_guide_view.dart', 'lib/screens/guide/line_guide.dart']),
    ('J', '공식 예고 상세', ['lib/screens/j_announcement_screen.dart']),
    ('M', '친구 서랍', ['lib/screens/m_friends_drawer.dart']),
    ('I', '내 정보 (친구 보기 · 사진 보기 포함)', ['lib/screens/i_profile_screen.dart']),
    ('L', '친구 컬렉션', ['lib/screens/l_friend_collection_screen.dart']),
    ('N', '알림', ['lib/screens/n_notifications_screen.dart']),
    ('K', '설정', ['lib/screens/k_settings_screen.dart']),
    ('V', '공유 카드 (내 컬렉션 · 도감 진행 그림)', ['lib/screens/v_share_sheet.dart']),
    ('W', '처음 데이터 받기', ['lib/screens/w_first_run_screen.dart']),
]


def sort_key(id_):
    m = re.match(r'([A-Z])-(\d+)([a-z]?)', id_)
    return (int(m.group(2)), m.group(3)) if m else (999, '')


def read_table(path):
    lines = open(path, encoding='utf8').read().splitlines()
    rows, notes, in_tab, after = [], [], False, False
    for ln in lines[:80]:
        if ln.startswith('// ┌'):
            in_tab = True
            continue
        if ln.startswith('// └'):
            in_tab, after = False, True
            continue
        if in_tab and ln.startswith('// │') and '번호 │' not in ln:
            cells = [c.strip() for c in ln[4:].split('│')]
            cells = [c for c in cells if c != ''] if cells[0] == '' and len(cells) > 4 else cells
            cells = (cells + [''] * 4)[:4]
            if cells[0] == '' and rows:  # 이어지는 줄 (번호 칸이 빈 줄)
                prev = rows[-1]
                rows[-1] = [prev[0], prev[1] + ' · ' + cells[1], prev[2] + ' · ' + cells[2], prev[3]]
            else:
                rows.append(cells)
        elif after:
            if ln.startswith('import ') or not ln.startswith('//'):
                break
            t = ln[2:].strip()
            if t:
                notes.append(t)
    return rows, notes


tables = {}
for key, name, files in SCREENS:
    rows, notes = [], []
    for f in files:
        r, n = read_table(f)
        rows += r
        notes += n
    rows.sort(key=lambda r: sort_key(r[0]))
    tables[key] = (name, files, rows, notes)

# 원칙별 요소
by_p = {f'P{i:02d}': [] for i in range(1, 11)}
for key, (name, files, rows, notes) in tables.items():
    for r in rows:
        for p in re.findall(r'P\d\d', r[3]):
            by_p[p].append(r[0])

db = json.load(open('mock_server/db.json', encoding='utf8'))
state_count = sum(open(p, encoding='utf8').read().count('STATE:') for p in glob.glob('lib/**/*.dart', recursive=True))
check = subprocess.run(
    ['grep', '-rnE', r'http\.(post|put|patch|delete)|SharedPreferences|sqflite|hive|FirebaseAuth|ChangeNotifierProvider|Riverpod|BlocProvider', 'lib/', 'pubspec.yaml'],
    capture_output=True, text=True, encoding='utf8')
check_out = check.stdout.strip()


def esc(s):
    return s.replace('|', '\\|')


out = []
w = out.append

w('# 디자인 가이드 — Hobby Atlas (hobbyDB v2 재설계 · 수집 도감 앱)')
w('')
w('> 기획 5단계 "화면 기획"(발표자료 부록 B5 화면별 요소 분석표)의 요약본입니다. **코드의 화면 파일 맨 위 대응표와 번호 · 명칭이 같아야** 합니다(UI 25점 "기획과 일치").')
w('> 3장 요소표는 각 화면 파일 맨 위 대응표에서 그대로 옮겼습니다. 화면을 바꾸면 코드 대응표 → 이 문서 → 원칙 카드 순서로 같이 고칩니다. 이 가이드에 없는 화면은 만들지 않습니다(감점).')
w('>')
w('> 2장 "현행 앱 근거"는 App Store 리뷰(2026-10-26 확인)를 한국어로 요약한 것 — 전체 표 · 별점 분포 · 유형 분류는 `docs/기획.md` 1장. 4장 각 규칙의 "의도"는 셀프 논증(`docs/셀프논증.md`)과 함께 확정합니다.')
w('')
w('## 0. 현행 앱과 v2 한 줄')
w('')
w('- **현행 앱**: hobbyDB: Collection Management — [App Store](https://apps.apple.com/us/app/hobbydb-collection-management/id1537173276) · ★4.8 · 평가 8.7K개 (2026-10-24 확인)')
w('- **v2 한 줄**: 관심 IP(채널)의 새 소식 · 발매일을 먼저 보여 주고, 가진 것과 갖고 싶은 것을 **좋아요 · 구매함 · 도감 점등**으로 한눈에 관리하며, 친구와 컬렉션을 나누는 피규어 · 프라모델 수집 앱')
w('- **이름 · 로고**: 앱 이름 `Hobby Atlas`(약칭 HA, 2026-10-29 확정 — 이전 임시 이름 Gunpula v2). 로고는 다음 단계(7장).')
ip = '건담 · 베이블레이드 X · 포켓몬 · 아머드 코어 · Fate'
w(f'- **데이터 범위(프로토타입)**: IP {len(db["franchises"])}개({ip}) · 상품 {len(db["kits"])} · 공식 예고 {len(db["announcements"])} · '
  f'건담 작품 도감 {len(db["guideWorks"])} · 기체 칸 {len(db["guideUnits"])} · 베이 {len(db["bbxTops"])} · 세대/작품 {len(db["worlds"])} · '
  f'알림 {len(db["notifications"])} · 친구 {len(db["profile"]["friends"])} · 게시물 {len(db["profile"]["showcase"])} — 모두 `mock_server/db.json` **GET**')
w('')

w('## 1. 화면 목록과 흐름')
w('')
w('| 화면 | 이름(비즈니스 명칭) | 파일 | 들어오는 방식(전환) | GET |')
w('|---|---|---|---|---|')
LIST = [
    ('S', '앱 셸', 's_app_shell.dart · main.dart', '첫 화면', '없음'),
    ('C', '채널 바 · 채널 관리', 'c_channel_screen.dart', '네 탭 위 공용 / 채널 관리 = 쌓기', '없음 (화면 안 상수)'),
    ('A', '홈', 'a_home_screen.dart', '옆으로(탭 1)', '`/kits?franchiseId=` · `/announcements?franchiseId=`'),
    ('B', '검색', 'b_search_screen.dart', '옆으로(탭 2) · 홈 검색창', '`/kits?franchiseId=`'),
    ('O', '전체 목록', 'o_see_all_screen.dart', '홈 › · 검색 결과 — 탭 안 보기(setState), 필터 = 덮기(dialog), 정렬 = 덮기(bottom sheet)', '없음 (부모 화면의 GET 결과)'),
    ('D', '상품 상세', 'd_kit_detail_screen.dart', '쌓기 / 넓은 화면은 오른쪽 칸 안에서 쌓기', '`/kits?franchiseId=` (같은 작품)'),
    ('E', '찍어서 찾기', 'e_camera_screen.dart', '쌓기(전체 화면) · 앨범 = 덮기(bottom sheet)', '`/kits?id=`'),
    ('H', '캘린더', 'h_calendar_screen.dart', '옆으로(탭 3)', '`/kits?franchiseId=` · `/announcements?franchiseId=`'),
    ('F', '컬렉션', 'f_collection_screen.dart', '옆으로(탭 4) · 휴지통 = 덮기(bottom sheet)', '`/kits?franchiseId=`'),
    ('G', '도감', 'g_guide_view.dart', '컬렉션 안의 보기(setState) · 작품 도감 · 종류 묶음 = 쌓기 · 기체 = 덮기', '`/guideWorks` · `/guideUnits?workId=` · `/bbxTops` · `/worlds?franchiseId=` · `/kits?id=` · `/kits?franchiseId=`'),
    ('J', '공식 예고 상세', 'j_announcement_screen.dart', '쌓기', '`/kits?franchiseId=`'),
    ('M', '친구 서랍', 'm_friends_drawer.dart', '덮기(Drawer — 아바타 · 홈 가장자리 밀기)', '`/profile` · `/guideWorks`'),
    ('I', '내 정보', 'i_profile_screen.dart', '쌓기 (서랍 머리 아바타 · 친구 줄)', '`/profile` · `/kits?franchiseId=` · `/guideWorks`'),
    ('L', '친구 컬렉션', 'l_friend_collection_screen.dart', '쌓기 (친구 프로필 숫자)', '`/kits?id=` · `/guideWorks`'),
    ('N', '알림', 'n_notifications_screen.dart', '쌓기 (🔔) · 친구 요청 = 덮기', '`/notifications` (+ 누를 때 `/kits?id=` · `/announcements` · `/profile`)'),
    ('K', '설정', 'k_settings_screen.dart', '쌓기 (⚙ · 알림의 ⚙)', '없음'),
]
for r in LIST:
    w(f'| {r[0]} | {r[1]} | `lib/screens/{r[2].split(" · ")[0]}`{" · `lib/main.dart`" if r[0] == "S" else ""} | {esc(r[3])} | {esc(r[4])} |')
w('')
w('```')
w('S 앱 셸  [옆으로(하단 탭): A 홈 | B 검색 | H 캘린더 | F 컬렉션]   위: 아바타 · 🔔 · ⚙ / C 채널 바')
w('  아바타 ──덮기(Drawer)──▶ M 친구 서랍 ──쌓기──▶ I 내 정보 ──쌓기──▶ L 친구 컬렉션')
w('                                    └─쌓기──▶ I 친구 보기(같은 화면) ──쌓기──▶ L')
w('  🔔 ──쌓기──▶ N 알림 ──쌓기──▶ D · J · I(친구)      ⚙ ──쌓기──▶ K 설정')
w('  카메라 ──덮기(시트)──▶ 사진 · 바코드 · 앨범 ──쌓기──▶ E 인식 결과 ──쌓기──▶ D')
w('A 홈 ── › ──▶ O 전체 목록(홈 안, 위 머리 그대로) ──쌓기──▶ D 상품 상세 · J 공식 예고')
w('B 검색 ── 처음 = O 전체 상품 / 검색창 누름 = 최근 · 인기 · AI ── 결과 = O ──쌓기──▶ D')
w('H 캘린더 ──쌓기──▶ D · J        F 컬렉션 [목록 | G 도감] ──쌓기──▶ D · 작품 도감 ──덮기──▶ 기체 시트')
w('D 상품 상세 ──덮기──▶ 시세 · 공식 정보 · 구매가 시트 · 제보 확인(dialog)')
w('```')
w('')
w('- **전환 3방식**: 쌓기(push/pop · CupertinoPageRoute) · 옆으로(하단 탭/측면 탭 + IndexedStack, 밑줄 탭) · 덮기(showModalBottomSheet · showDialog · showGeneralDialog(필터 패널) · Drawer(친구 서랍)).')
w('  탭 **안에서** 바뀌는 보기(O 전체 목록 · G 도감 · 검색 판)는 새 화면이 아니라 그 화면의 `setState` 표시 변화입니다.')
w('- **적응형** (창 너비 · 높이 기준, `MediaQuery.sizeOf` · `LayoutBuilder`, 기기 종류 · 방향 고정 없음):')
w('  - 폰(너비 < 700): 위 아바타 줄 + 채널 바, 바닥 탭 바. 아래로 스크롤하면 탭 바와 아바타 줄이 접힘(S-8 · S-13)')
w('  - 가로로 눕힌 폰(너비 > 높이 · 높이 < 520): 측면 탭(S-5) — 아바타 / 탭 4개 / 🔔 ⚙, 높이가 모자라면 측면 탭만 스크롤')
w('  - 폴드 펼침 · 태블릿 · 넓은 창(너비 ≥ 700): **반반 화면**(S-12) — 왼쪽 = 폰 화면 그대로, 오른쪽 = 자세히 칸. 폴드 접힘선(`displayFeatures`)이 있으면 거기서, 없으면 왼쪽 45%(320–460)')
w('  - D 상품 상세: 칸 너비 ≥ 720이면 사진 왼쪽 · 정보 오른쪽(D-13). H 캘린더: ≥ 720이면 달력 왼쪽 · 목록 오른쪽(H-7)')
w('  - 격자(O · G · 게시물): 칸 너비로 열 수 계산. A 배너 높이 ≤ 화면 높이의 절반')
w('  - 확인: `test/layout_test.dart` — 320×568 · 390×844 · 844×390 · 690×830 · 830×690 · 768×1024 · 1280×800 에서 주요 화면 넘침 0 (`flutter test`)')
w('')

NAMES = {
    'P01': '시스템 상태의 가시성', 'P02': '시스템과 실세계의 일치', 'P03': '사용자 통제와 자유', 'P04': '일관성과 표준',
    'P05': '오류 예방', 'P06': '기억보다 재인', 'P07': '사용의 유연성과 효율성', 'P08': '미학적이고 미니멀한 디자인',
    'P09': '오류 인식·진단·복구 돕기', 'P10': '도움말과 문서',
}
EVID = {
    'P01': '2025-07-28 ★3: 바코드 스캐너가 몇 번 만에 멈추거나 꺼진다(무엇이 되는지 알 수 없음)',
    'P02': '현행 캡처: 미국 경매가(달러) 위주 — 일본 정가 · 원래 이름이 없다 / 잘된 점: 상자 사진 · 품번',
    'P03': '2023-04-18 ★5: 누를 때마다 다른 창이 열려 다시 돌아와야 함 · 2025-08-08 ★1: 처음 화면으로 튕김',
    'P04': '2023-11-23 ★5: 쇼케이스와 컬렉션의 차이를 모르겠다',
    'P05': '2025-08-08 ★1: 원치 않는 새로고침 · 리셋',
    'P06': '2023-11-23 ★5: 오래 썼지만 인터페이스를 익히기 어렵다',
    'P07': '2025-11-30 ★1: 시세를 한 달 10번만 볼 수 있게 막음',
    'P08': '2023-04-18 ★5: "the layout is a pain" · 2025-11-30 ★1: 한 화면에 광고가 너무 많다',
    'P09': '2021-03-22 ★2: 없는 상품을 추가 · 오류 표시할 방법이 없다 · 2023-11-23: 일반판이 자주 빠짐',
    'P10': '2021-09-17 ★3: 시세가 어디서 나온 값인지 모르겠다',
}
KEY = {
    'P01': '로딩 · 진행 막대 · 안 읽은 점 · 개수 표시 · 레벨',
    'P02': '공식 사진 · 엔화 일본 정가 · 일본어 원래 이름 · 공식 예고 원본 이미지',
    'P03': '모든 토스트 "되돌리기" · 휴지통 · IndexedStack 탭 상태 유지 · 뒤로 = 보던 곳',
    'P04': '♡ = 좋아요 · 리본 = 구매함 · 파랑/민트 뜻 고정 · 같은 부품(ProductTile · ThumbRow · GpSearchBar) · 앱 전체 한 벌',
    'P05': '삭제 · 제보 · 로그아웃 전 확인 · 사진 인증 판정 · 공개 범위',
    'P06': '보이는 채널 바 · 밑줄 탭 · 최근/인기 검색어 · 필터 패널 체크',
    'P07': '♡ · 리본 바로 누르기 · 카메라 지름길 · 홈 › 전체 목록 · 숫자 누르면 이동',
    'P08': '흑백 + 포인트 두 색 · 글자 6단계 · 홈 줄은 사진 + 이름만 · 접히는 머리/탭 바',
    'P09': 'ErrorView + 다시 시도 · 빈 상태 + 빠져나갈 길 · 사진 판정 실패 안내',
    'P10': '도감 읽는 법(?) · 출처 · 공식으로 가기 · "가짜" 고지 · 도움말',
}
VIDEO = {'P01': 'p01.mp4', 'P03': 'p03.mp4', 'P04': 'p04.mp4', 'P06': 'p06.mp4', 'P07': 'p07.mp4', 'P09': 'p09.mp4'}

w('## 2. 원칙 표 P01–P10 (P번호 = 닐슨 원칙 번호)')
w('')
w('"v2 적용" 요소 번호는 3장 요소표(= 코드 대응표)의 원칙 칸에서 모은 것입니다. 현행 앱 근거는 App Store 리뷰 요약(날짜 · 별점, 작성자 이름 지움) — `docs/기획.md` 1-3.')
w('')
w('| P번호 | 닐슨 원칙 | 현행 앱 근거(리뷰 · 캡처) | v2에서 대표로 보여 줄 것 | v2 적용(요소 번호) | 코드에서 찾기 | 영상 |')
w('|---|---|---|---|---|---|---|')
for p in by_p:
    ids = by_p[p]
    w(f'| {p} | {NAMES[p]} | {EVID[p]} | {KEY[p]} | {" · ".join(ids)} | `grep -rn "{p}" lib` | {VIDEO.get(p, "")} |')
w('')
w('해당 없음 원칙: 없음 — 10개 모두 v2 화면 요소가 있습니다.')
w('')

w('## 3. 요소 분석 (화면마다 한 표 — 코드 대응표와 같은 번호)')
w('')
w('각 표 아래의 "전환 · 메모"는 같은 파일 맨 위 주석입니다(현행 앱 문제 → v2 해결 포함).')
w('')
for key, (name, files, rows, notes) in tables.items():
    w(f'### 화면 {key} — {name}')
    w('')
    w('파일: ' + ' · '.join(f'`{f}`' for f in files))
    w('')
    w('| 번호 | Flutter 위젯명 | 비즈니스 명칭(한글) | 원칙(P번호) |')
    w('|---|---|---|---|')
    for r in rows:
        w(f'| {esc(r[0])} | {esc(r[1])} | {esc(r[2])} | {esc(r[3])} |')
    if notes:
        w('')
        for n in notes:
            w(f'- {n}')
    w('')

w('## 4. 디자인 가이드 글 — 모든 화면이 따르는 규칙')
w('')
RULES = [
    ('색의 뜻 (S-15 · `lib/theme.dart`)',
     '색만 보고도 "고를 수 있는 것"과 "이미 가진 것"을 구분하게 한다.',
     '바탕은 흑백(검정 #111 · 회색 · 흰색). 포인트는 두 가지뿐: **파랑**(Gp.accent) = 고름 · 누를 수 있음 · 좋아요 · 안 읽음, **민트**(Gp.own) = 가진 것(구매함 리본 ✓ · 구매함 칸 테두리 · 인증 배지 · 수집 막대). 빨강은 삭제 · 로그아웃에만. 상품 사진 외의 큰 검정 바탕 + 흰 글자 면은 쓰지 않는다.',
     'P04 · P08'),
    ('모양의 뜻 — ♡ · 리본 · 배지 (A-9 · D-6 · G-4b · O-4)',
     '같은 행동은 어느 화면에서나 같은 모양으로 누른다.',
     '♡ = 좋아요(갖고 싶다), 책갈피 리본 + → ✓ = 구매함(가졌다), 🏅 배지 · 도는 색 고리 = 내 사진으로 인증. 상품 사진 위에서는 왼쪽 위 리본 · 왼쪽 아래 ♡ (MarkOverlay 하나), 버튼일 때는 같은 아이콘의 TogglePill. 컬렉션 탭 아이콘은 리본과 겹치지 않게 모자이크 격자.',
     'P04 · P06'),
    ('도감 4단계와 레벨 (G-4 · G-4a)',
     '하나 더 모을 때마다 "올라간다"는 느낌을 준다.',
     '칸: 흑백(없음) → 컬러(♡ 좋아요) → 컬러 + 초록 테두리(리본 구매함) → 내 사진 + 도는 고리 + 배지(사진 인증). 1 · 2 · 3점, 5점마다 작품 Lv 상승(막대 애니메이션 · 토스트). 읽는 법은 긴 범례 대신 ? 버튼(G-2).',
     'P01 · P10'),
    ('글자 6단계 (S-15)',
     '크기만 보고 정보의 높낮이를 알게 한다.',
     'Gp.t11(배지 · 시간) · t12 = 12.5(보조 글) · t14(본문 · 버튼) · t16(시트 제목) · t19(화면 · 섹션 제목 · 상품명) · t24(가격 · 큰 숫자). 이 밖의 크기는 쓰지 않는다(코드에 숫자로 쓴 글자 크기 0개).',
     'P08 · P04'),
    ('면과 층 (A-8)',
     '줄과 줄 사이 경계를 선 없이 보이게 한다.',
     '회백색 바탕(#F7F7F5) 위에 흰 띠(SectionPanel)를 10dp 틈으로 쌓는다. 제목 앞에는 파랑 막대(SectionHeader). 떠 있는 흰 버튼(Gp.raised)은 아바타 · 카메라 · 채널 타일에만.',
     'P08'),
    ('접근성',
     '작은 화면 · 큰 손가락 · 낮은 시력에서도 쓸 수 있게 한다.',
     '보조 글자 #767676 이상(흰 바탕 대비 4.5:1, WCAG AA). 사진 위 ♡ · 리본 누르는 자리 44dp, 작은 × 40dp. 좁은 화면에서 글자는 말줄임 · 줄바꿈 · 축소(넘침 0을 테스트로 확인).',
     'P08 · P09'),
    ('되돌리기와 확인 (F-7 · F-10 · D-12 · K-5)',
     '실수해도 바로 되돌릴 수 있게, 되돌릴 수 없는 일은 한 번 묻는다.',
     '켜고 끄는 일(좋아요 · 구매함 · 점등 · 읽음 · 알림 지우기)은 바로 하고 토스트에 "되돌리기". 여러 개 삭제 · 제보 · 로그아웃 · 기록 지우기는 먼저 확인 대화상자. 지운 상품은 휴지통에서 다시 켬.',
     'P03 · P05'),
    ('표기 (D-5 · O-4)',
     '같은 정보는 같은 모양으로 쓴다.',
     '날짜는 어디서나 2027.09 · 2026.10.16 (dateDot). 엔화 = 일본 정가(상세 가격 위 "일본 정가"), 원화 = 국내 시세 · 내 구매가. 건담 작품명은 영어(The Witch from Mercury · Hathaway …), 한글 줄임말은 검색어로만 남김.',
     'P02 · P04'),
    ('한 벌로 이어지는 상태 (S-16)',
     '한 곳에서 바꾼 것이 다른 화면에서도 같게 보이게 한다.',
     '좋아요 · 구매함은 맨 위 MarksHost 하나(setState 를 위로 올림): 홈 카드에서 ♡ → 컬렉션 목록 · 상세 버튼 · 내 정보 숫자 · 친구 컬렉션 "나도 있음"이 같이 바뀐다. 반반 화면의 "오른쪽에 연 것"도 PaneHost 하나 → 왼쪽 카드 테두리 · 줄 바탕.',
     'P04 · P01'),
    ('가짜 기능은 가짜라고 (AGENTS.md)',
     '실제 동작 없이도 흐름을 끝까지 보여 준다.',
     'AI 검색 후보 · 카메라 인식 · 사진 인증 판정은 미리 쓴 결과. 백업 · 복원 · 로그아웃 · 공식 링크 · 친구 요청 · 사진 저장 · 알림 받기 · 제보는 토스트로만 응답(저장 · 전송 없음). 문구는 앱처럼 자연스럽게 쓰고, "가짜"라는 사실은 이 문서와 발표에서 밝힌다.',
     'P10'),
]
for title, aim, body, p in RULES:
    w(f'### {title}')
    w(f'- **목적**: {aim}')
    w(f'- **내용**: {body}')
    w(f'- **의도**: {p} — 셀프 논증 후 확정')
    w('')

w('## 5. 상태관리 포인트')
w('')
w(f'코드에는 `// STATE: <데이터> → <보여질 위젯>` 주석으로 표시합니다(현재 {state_count}곳, 모아 보기: `grep -rn "STATE:" lib`).')
w('화면 안 표시 변화는 그 화면의 `setState`로만 바꿉니다. 여러 화면에 걸친 값(좋아요 · 구매함 · 오른쪽 칸에 연 것)은 **맨 위 StatefulWidget 의 setState + InheritedWidget** 으로 내려 줍니다(상태관리 패키지 없음). 영구 저장은 하지 않아 앱을 끄면 db.json 의 처음 값으로 돌아갑니다.')
w('')
w('| 바뀌는 데이터 | 어디서 바뀌나 | 보이는 곳 | 코드 |')
w('|---|---|---|---|')
STATES = [
    ('좋아요 · 구매함 (앱 전체)', 'A-9 · O-4 · D-6 · E-7 · F-6 삭제 · F-10 복원', '모든 카드의 ♡ · 리본 · D-6 버튼 · F-2 개수 · F-5 목록 · I-4 숫자 · L-2 겹침', '`lib/marks.dart` (MarksHost)'),
    ('반반 화면 오른쪽에 연 것', 'openPage (D · J · I 친구)', '왼쪽 ProductTile 테두리 · ThumbRow 바탕', '`lib/detail_pane.dart` (PaneHost)'),
    ('내 채널 · 고른 채널', 'C-1 · C-4 · C-5', 'A · B · H · F 목록과 범위, G 도감, N 알림 범위', '`s_app_shell.dart` · `c_channel_screen.dart`'),
    ('지금 탭 · 탭 바 · 위 줄 보임', 'S-3 · 스크롤 방향', 'S-6 · S-8 · S-13', '`s_app_shell.dart`'),
    ('홈 전체 목록 · 목록 안 검색어', 'A-5 › · O-7', 'O 목록 · 머리 검색창 문구', '`a_home_screen.dart`'),
    ('필터 · 정렬 · 보기 방식', 'O-2 · O-3 · O-1', 'O-4 격자/목록 · 고른 조건 줄', '`o_see_all_screen.dart`'),
    ('검색어 · 검색창 포커스', 'B-2 · B-3 · B-4 · B-5', 'B 판 ↔ O 전체 상품 · 검색 결과 · B-6 후보', '`b_search_screen.dart`'),
    ('도감 칸 단계 · 내 사진', 'G-4b · G-5b · G-5c', 'G-4 칸 · G-4a Lv', '`g_guide_view.dart` (그 작품 화면 안)'),
    ('게시물 공개 범위 · 숨긴 사진 · 워터마크', 'I-9 · I-10 · I-7', 'I-6 게시물 칸 · 제목 줄', '`i_profile_screen.dart` (내 정보 화면 안)'),
    ('알림 읽음 · 지움 · 탭', 'N-4 · N-5 · N-6 · N-1', 'N-3 점 · 굵은 제목 · 탭 개수', '`n_notifications_screen.dart`'),
    ('휴지통', 'F-6 · F-7 · F-10', 'F-10 배지 개수 · 시트 목록', '`f_collection_screen.dart`'),
]
for r in STATES:
    w('| ' + ' | '.join(esc(c) for c in r) + ' |')
w('')

w('## 6. 규칙(AGENTS.md) 점검')
w('')
w('| 규칙 | 지키는 방법 |')
w('|---|---|')
w('| 전환 3방식 | 쌓기(CupertinoPageRoute) · 옆으로(탭 + IndexedStack, 밑줄 탭) · 덮기(bottom sheet · dialog · Drawer · 필터 패널 showGeneralDialog). 반반 화면 오른쪽 칸도 칸 안 Navigator 의 push/pop |')
w('| GET 만 | 요청은 `lib/api.dart` 의 `_get` 하나(json-server). post/put/patch/delete 없음 |')
w('| setState 만 | 화면 안 = 그 화면 setState, 여러 화면 = 맨 위 setState + InheritedWidget(MarksHost · PaneHost). ValueNotifier/ChangeNotifier 0개 |')
w('| 3상태 | GET 하는 화면 모두 LoadingView · ErrorView · EmptyView (`--dart-define=DEMO_STATE=loading/error/empty` 로 시연) |')
w('| 창 너비 적응형 | 1장 "적응형" — 기기 종류 · 방향 고정 없음, 7가지 크기 테스트 |')
w('| 패키지 | `http` 하나 (pubspec 그대로) |')
w('| 실제 동작 없음 | 로그인 · 결제 · 저장 · LLM 호출 없음, 4장 "가짜 기능은 가짜라고" |')
w(f'| 자가 점검 grep | `grep -rnE "http\\.(post|put|patch|delete)|SharedPreferences|sqflite|hive|FirebaseAuth|ChangeNotifierProvider|Riverpod|BlocProvider" lib/ pubspec.yaml` → {"결과 없음 ✅" if not check_out else "확인 필요: " + esc(check_out)} |')
w('')

w('## 7. 알려진 한계 · 다음 단계 (발표에서 먼저 말할 것)')
w('')
for t in [
    '**저장 없음**: 좋아요 · 구매함 · 점등 · 게시물 공개 범위 · 읽음 등은 앱을 끄면 처음 값으로 돌아간다(규칙: 영구 저장 금지).',
    '**도감 칸 상태**는 그 작품 도감 화면 안에서만 유지된다 — 기체(도감 칸)와 상품은 다른 단위라 앱 전체 한 벌(MarksHost)에 넣지 않았다.',
    '**게시물 공개 범위 · 숨긴 사진**은 내 정보 화면 안에서만 유지된다.',
    '**폴드를 접으면** 오른쪽 칸에 열려 있던 화면은 닫힌다(왼쪽 탭 상태는 유지).',
    '**🔔 의 점**은 늘 보인다(안 읽은 알림 수를 셸에서 다시 GET 하지 않음). 설정의 "내 채널 소식만" 스위치는 표시만 바뀐다.',
    '**앱 아이콘**: 도감 칸으로 된 지구 + 아바타와 같은 파랑→연두 고리 (tool/make_app_icon.py, 10/29). 글자 로고는 다음 단계.',
]:
    w(f'- {t}')
w('')

open('docs/디자인가이드.md', 'w', encoding='utf8').write('\n'.join(out))
print('written', len(out), 'lines;', {k: len(v[2]) for k, v in tables.items()}, 'check:', repr(check_out[:80]))
