// IP 채널 목록 — 하드코딩 상수 (AGENTS.md: 데이터는 상수 또는 GET).
// "내 채널"은 사람마다 다르므로 앱 셸이 들고 있고, 채널 관리 화면에서 바꾼다 (모두에게 같은 IP 를 고정하지 않는다).
class Channel {
  const Channel({required this.id, required this.label, this.image = '', this.hasData = true});

  /// 카탈로그 kit 의 franchise 와 같은 값
  final String id;
  final String label;

  /// 채널 아이콘(상품 사진을 원으로 자름). 비어 있으면 첫 글자.
  final String image;

  /// false = 아직 수록 상품이 없는 IP (빈 상태를 보여 준다)
  final bool hasData;
}

const allChannels = <Channel>[
  Channel(id: 'gundam', label: '건담', image: 'assets/gp/kits/gu02.jpg'),
  Channel(id: 'beyblade', label: '베이블레이드 X', image: 'assets/gp/parts/bx-01-blade.png'),
  Channel(id: 'pokemon', label: '포켓몬', image: 'assets/gp/worlds/po_gen1.png'),
  Channel(id: 'armored_core', label: '아머드 코어', image: 'assets/gp/worlds/ar_ac6.jpg'),
  Channel(id: 'fate', label: 'Fate', image: 'assets/gp/worlds/fa_stay_night.jpg'),
  Channel(id: 'madoka', label: '마도카 마기카', image: 'assets/gp/worlds/ma_madoka.jpg'),
  Channel(id: 'lego', label: '레고', image: 'assets/gp/worlds/le_lego.jpg'),
  // 게임 · 본체 · 주변기기 · amiibo · 캐릭터 굿즈 (Gunpula 2026-11-14). 앱 안 그림을 새로 넣으면 APK 를 새로 내야 해서
  // 그림은 atlas-groups `channels.nintendo.image` (없으면 첫 글자). 처음 내 채널에는 없다 — 고르기 전엔 아무것도 받지 않는다
  Channel(id: 'nintendo', label: '닌텐도'),
  Channel(id: 'kamen_rider', label: '가면라이더', hasData: false),
  Channel(id: 'evangelion', label: '에반게리온', hasData: false),
  Channel(id: 'ultraman', label: '울트라맨', hasData: false),
  Channel(id: 'dragon_ball', label: '드래곤볼', hasData: false),
  Channel(id: 'one_piece', label: '원피스', hasData: false),
  Channel(id: 'macross', label: '마크로스', hasData: false),
  Channel(id: 'zoids', label: '조이드', hasData: false),
];

/// 채널 대표 그림 — Gunpula atlas-groups.json `channels` 의 공식 그림 (Catalog 가 채운다). 없으면 위 기본 그림
final channelCovers = <String, String>{};

/// 종류별 도감 카드의 공식 그림 — atlas-groups.json `line_covers` (채널 → 종류 이름 → 그림, Catalog 가 채운다).
/// 종류 이름 = 앱의 라인 이름(lib/data/gunpula.dart lineLabel). 없으면 그 종류의 최근 상품 사진
final lineCovers = <String, Map<String, String>>{};

/// Gunpula 에 상품 파일이 있는 채널 (manifest `franchises`, Catalog 가 채운다). 비어 있으면 모름 → 위 hasData 그대로.
/// 앱이 먼저 아는 새 채널(닌텐도)은 Gunpula 가 파일을 내기 전까지 회색으로
final channelsWithData = <String>{};

/// 처음 설치했을 때의 내 채널
const defaultMyChannels = ['gundam', 'beyblade', 'pokemon'];

Channel channelOf(String id) {
  final c = allChannels.firstWhere(
    (c) => c.id == id,
    orElse: () => Channel(id: id, label: id, hasData: false),
  );
  final cover = channelCovers[id];
  final hasData = c.hasData && (channelsWithData.isEmpty || channelsWithData.contains(id));
  if ((cover == null || cover.isEmpty) && hasData == c.hasData) return c;
  return Channel(id: c.id, label: c.label, image: cover == null || cover.isEmpty ? c.image : cover, hasData: hasData);
}
