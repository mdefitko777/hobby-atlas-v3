// 종류별 도감 테스트용 상품 한 개 (Kit 생성자의 필수 칸을 채운다)
import 'package:hobby_atlas/models.dart';

Kit lineKit(
  String id, {
  String channel = 'gundam',
  String line = 'HG',
  String type = '프라모델',
  String goodsKind = '',
  String date = '2024-01-01',
  String image = 'assets/gp/kits/gu01.jpg',
  String? name,
  bool imageRef = false,
  bool pb = false,
  CollectStatus status = CollectStatus.none,
}) {
  final n = name ?? '$line $id';
  return Kit(
    id: id,
    franchiseId: channel,
    name: n,
    nameJa: '',
    series: '',
    line: line,
    type: type,
    scale: '',
    universe: '',
    date: date,
    priceJpy: null,
    image: image,
    gallery: const [],
    limited: false,
    pb: pb,
    status: status,
    wantedQty: 0,
    recent: false,
    month: false,
    market: null,
    keywords: const [],
    goodsKind: goodsKind,
    imageRef: imageRef,
    blob: [n, line, type, goodsKind].join(' ').toLowerCase(),
  );
}
