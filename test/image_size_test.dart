// 점검(2026-11-14): 그림을 칸 크기만큼만 푸는 셈 · 레고 작은 그림 주소 · Gunpula 작은 그림 목록 (lib/logic/image_size.dart)
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/logic/image_size.dart';

void main() {
  test('칸 한 변은 64 px 단위로 올린다 (끝없는 변은 그대로)', () {
    expect(decodeBucket(156), 192); // 52 dp × 3
    expect(decodeBucket(192), 192);
    expect(decodeBucket(10), 64);
    expect(decodeBucket(double.infinity), double.infinity);
  });

  test('잘라 채우기(cover): 짧은 변이 칸을 채우는 만큼', () {
    // 정사각 칸에 가로로 긴 그림 → 세로가 칸 높이
    expect(decodeSize(2400, 1200, 192, 192, DecodeFit.cover), (width: 384, height: 192));
    // 세로로 긴 그림 → 가로가 칸 너비
    expect(decodeSize(1000, 1414, 192, 192, DecodeFit.cover), (width: 192, height: 272));
    // 860² 상품 사진 → 192²
    expect(decodeSize(860, 860, 192, 192, DecodeFit.cover), (width: 192, height: 192));
  });

  test('안에 맞추기(contain): 긴 변이 칸에 들어가는 만큼', () {
    expect(decodeSize(2400, 1200, 192, 192, DecodeFit.contain), (width: 192, height: 96));
    expect(decodeSize(1200, 675, 1024, double.infinity, DecodeFit.contain), (width: 1024, height: 576));
  });

  test('칸보다 작은 그림 · 크기를 모르는 칸은 그대로 (키우지 않는다)', () {
    expect(decodeSize(560, 560, 640, 640, DecodeFit.cover), isNull);
    expect(decodeSize(560, 560, double.infinity, double.infinity, DecodeFit.contain), isNull);
    expect(decodeSize(0, 0, 100, 100, DecodeFit.cover), isNull);
  });

  test('너비 맞추기 · 늘려 채우기', () {
    expect(decodeSize(2000, 3000, 1024, double.infinity, DecodeFit.width), (width: 1024, height: 1536));
    expect(decodeSize(2000, 3000, 1024, 512, DecodeFit.fill), (width: 1024, height: 512));
  });

  test('레고(Rebrickable) 표지는 칸에 맞는 작은 그림 주소, 다른 곳은 그대로', () {
    const set = 'https://cdn.rebrickable.com/media/sets/31209-1.jpg';
    expect(imageThumbUrl(set, 192), 'https://cdn.rebrickable.com/media/thumbs/sets/31209-1.jpg/250x250p.jpg');
    expect(imageThumbUrl(set, 448), 'https://cdn.rebrickable.com/media/thumbs/sets/31209-1.jpg/500x500p.jpg');
    expect(imageThumbUrl(set, 1088), set);
    expect(imageThumbUrl(set, double.infinity), set);
    const shard = 'https://mdefitko777.github.io/gunpula-img-2/catalog/a.jpg';
    expect(imageThumbUrl(shard, 192), shard);
  });

  // Gunpula img-contract v1 (2026-11-14) 의 예와 같은 모양
  const shard = 'https://mdefitko777.github.io/gunpula-img-2/catalog/pokemon/a-01-b6e76f25b4.jpg';
  const shardThumb = 'https://mdefitko777.github.io/gunpula-img-3/thumbs/repo/catalog/pokemon/a-01-b6e76f25b4.jpg.webp';
  const akamai = 'https://bandai-a.akamaihd.net/bc/img/model/b/1000256190_1.jpg';
  const akamaiThumb =
      'https://mdefitko777.github.io/gunpula-img-3/thumbs/web/bandai-a.akamaihd.net/3f2a9c0d41b7e8a6.webp';
  final file = jsonEncode({
    'schema': 'gunpula-thumbs-v1',
    'generated_at': '2026-11-14T09:00:00.000Z',
    'max_side': 400,
    'rules': [
      {'prefix': 'https://example.com/media/', 'thumb_prefix': 'https://example.com/thumbs/', 'thumb_suffix': '/s.jpg'},
    ],
    'thumbs': {shard: shardThumb, akamai: akamaiThumb, 'https://x/raw.jpg': 'http://insecure/raw.webp'},
  });

  test('작은 그림 목록: 작은 칸은 목록의 작은 그림, 큰 칸 · 목록에 없는 주소는 원본', () {
    final t = parseThumbIndex(file);
    expect(t.maxSide, 400);
    expect(imageThumbUrl(shard, 192, t), shardThumb); // 알림 52 dp × 3
    expect(imageThumbUrl(akamai, 320, t), akamaiThumb); // 「전체 보기」 칸 × 2.625
    expect(imageThumbUrl(akamai, 384, t), akamai, reason: '400 px 그림을 384 px 칸에 잘라 채우면 짧은 변이 모자라 흐리다');
    expect(imageThumbUrl(akamai, 1088, t), akamai, reason: '상품 상세 사진 넘기기는 원본');
    expect(imageThumbUrl('https://other.host/a.jpg', 192, t), 'https://other.host/a.jpg');
    expect(
      imageThumbUrl('https://example.com/media/sets/1.jpg', 192, t),
      'https://example.com/thumbs/sets/1.jpg/s.jpg',
    );
    expect(imageThumbUrl('https://x/raw.jpg', 192, t), 'https://x/raw.jpg', reason: 'https 가 아닌 작은 그림은 버린다');
    // 레고는 앱 규칙(칸에 맞춰 250 · 500)이 먼저
    expect(
      imageThumbUrl('https://cdn.rebrickable.com/media/sets/31209-1.jpg', 192, t),
      'https://cdn.rebrickable.com/media/thumbs/sets/31209-1.jpg/250x250p.jpg',
    );
  });

  test('작은 그림 목록이 없거나(옛 데이터 · 404) 모양이 다르면 원본 그대로', () {
    for (final bad in [
      '',
      'not json',
      '[]',
      jsonEncode({
        'schema': 'gunpula-thumbs-v2',
        'thumbs': {shard: shardThumb},
      }),
    ]) {
      final t = parseThumbIndex(bad);
      expect(t.isEmpty, isTrue, reason: bad);
      expect(imageThumbUrl(shard, 192, t), shard);
    }
    expect(imageThumbUrl(shard, 192, ThumbIndex.none), shard);
  });
}
