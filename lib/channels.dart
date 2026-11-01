// IP 채널 목록 — 하드코딩 상수 (AGENTS.md: 데이터는 상수 또는 GET).
// "내 채널"은 사람마다 다르므로 앱 셸이 들고 있고, 채널 관리 화면에서 바꾼다. (현행 앱: 상단 5개 IP 고정)
class Channel {
  const Channel({required this.id, required this.label, this.image = '', this.hasData = true});

  /// db.json kits.franchiseId 와 같은 값
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

/// 처음 설치했을 때의 내 채널
const defaultMyChannels = ['gundam', 'beyblade', 'pokemon'];

Channel channelOf(String id) {
  final c = allChannels.firstWhere(
    (c) => c.id == id,
    orElse: () => Channel(id: id, label: id, hasData: false),
  );
  final cover = channelCovers[id];
  return cover == null || cover.isEmpty ? c : Channel(id: c.id, label: c.label, image: cover, hasData: c.hasData);
}
