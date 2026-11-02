// 조립 상태 · 예약 · 바코드 겹침 — 규칙(lib/logic) + 저장 모양(UserStore local_state 'build_status' · 'preorders')
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/data/user_store.dart';
import 'package:hobby_atlas/logic/build_status.dart';
import 'package:hobby_atlas/logic/collection_rules.dart';
import 'package:hobby_atlas/logic/preorder.dart';
import 'package:hobby_atlas/models.dart';
import 'package:hobby_atlas/notifications/notify_store.dart' show preorderDuesFor;

Kit kit(String id, {String jan = ''}) => Kit(
  id: id,
  franchiseId: 'gundam',
  name: '상품 $id',
  nameJa: '',
  series: '',
  line: 'HG',
  type: '',
  scale: '',
  universe: '',
  date: '2026-12',
  priceJpy: 2000,
  image: '',
  gallery: const [],
  limited: false,
  pb: false,
  status: CollectStatus.none,
  wantedQty: 0,
  recent: false,
  month: false,
  market: null,
  keywords: const [],
  jan: jan,
);

void main() {
  group('조립 상태 규칙', () {
    test('조립하는 상품만: 프라모델 · 조립식 식완 / 가샤폰 — 피규어 · 인형 · 굿즈는 아님', () {
      Kit k(String type, String line, {String franchise = 'gundam'}) =>
          Kit.fromJson({'id': 'x', 'type': type, 'line': line, 'franchiseId': franchise})!;
      expect(needsAssembly(k('프라모델', 'HG')), isTrue);
      expect(needsAssembly(k('프라모델', 'NG')), isTrue); // 옵션 파츠 세트
      expect(needsAssembly(k('프라모델', 'POKEPLA', franchise: 'pokemon')), isTrue);
      expect(needsAssembly(k('식완', 'G FRAME FA')), isTrue);
      expect(needsAssembly(k('가샤폰', 'MS 앙상블')), isTrue);
      expect(needsAssembly(k('식완', '식완', franchise: 'armored_core')), isTrue); // 어셈블 컬렉션
      expect(needsAssembly(k('피규어', 'ROBOT魂')), isFalse);
      expect(needsAssembly(k('식완', 'CONVERGE')), isFalse);
      expect(needsAssembly(k('인형', '봉제인형', franchise: 'pokemon')), isFalse);
      expect(needsAssembly(k('굿즈', '굿즈')), isFalse);
    });

    test('단계 순환 · 글자 · 모르는 값은 미조립', () {
      expect(BuildStage.unbuilt.next, BuildStage.building);
      expect(BuildStage.building.next, BuildStage.built);
      expect(BuildStage.built.next, BuildStage.unbuilt);
      expect(BuildStage.parse('built'), BuildStage.built);
      expect(BuildStage.parse('weird'), BuildStage.unbuilt);
      expect(BuildStage.values.map((s) => s.label), ['미조립', '조립 중', '완성']);
    });

    test('미조립 수 · 단계별 수 (기록 없음 = 미조립)', () {
      final rec = {'a': BuildStage.built, 'b': BuildStage.building};
      BuildStage of(String id) => rec[id] ?? BuildStage.unbuilt;
      expect(backlogCount(['a', 'b', 'c', 'd'], of), 2);
      expect(stageCounts(['a', 'b', 'c'], of), {BuildStage.unbuilt: 1, BuildStage.building: 1, BuildStage.built: 1});
      expect(buildFilterAt(0), isNull);
      expect(buildFilterAt(1), BuildStage.unbuilt);
      expect(buildFilterAt(3), BuildStage.built);
    });

    test('저장 모양 왕복 · 깨진 줄 버림', () {
      final m = buildRecordsFrom({
        'a': {'stage': 'building', 'painted': true, 'updated_at': 't1'},
        'b': 'x',
      });
      expect(m.keys, ['a']);
      expect(m['a']!.toJson(), {'stage': 'building', 'painted': true, 'updated_at': 't1'});
      expect(const BuildRecord().isDefault, isTrue);
    });
  });

  group('예약 규칙', () {
    test('도착 예정 글자 정리', () {
      expect(normalizeArrival('2026-12'), '2026-12');
      expect(normalizeArrival('2026.3'), '2026-03');
      expect(normalizeArrival('2026/12/5'), '2026-12-05');
      expect(normalizeArrival('2026년 12월 15일'), '2026-12-15');
      expect(normalizeArrival('2026-13'), '');
      expect(normalizeArrival('다음 달'), '');
      expect(arrivalLabel('2026-12-05'), '2026.12.05');
    });

    test('낼 돈 = 총액 − 예약금 (결제 완료면 0) · 이번 달 합', () {
      const a = Preorder(price: 10000, deposit: 3000, arrival: '2026-12');
      const b = Preorder(price: 5000, paid: true, arrival: '2026-12-20');
      const c = Preorder(price: 8000, arrival: '2027-01');
      const gone = Preorder(price: 9000, arrival: '2026-12', deleted: true);
      const came = Preorder(price: 9000, arrival: '2026-12', arrivedAt: 't');
      expect(a.due, 7000);
      expect(b.due, 0);
      expect(const Preorder(price: 1000, deposit: 5000).due, 0);
      final all = {'a': a, 'b': b, 'c': c, 'g': gone, 'h': came};
      expect(monthDue(all, DateTime(2026, 12)), (total: 7000, count: 1));
      expect(monthDue(all, DateTime(2027, 1)), (total: 8000, count: 1));
      expect(arrivingIn(all, DateTime(2026, 12)).map((e) => e.key), ['a', 'b']);
    });

    test('저장 모양 왕복', () {
      const p = Preorder(shop: 'PB', price: 8800, deposit: 1000, arrival: '2026-12', updatedAt: 't');
      expect(p.toJson(), {
        'shop': 'PB',
        'price': 8800,
        'deposit': 1000,
        'paid': false,
        'arrival': '2026-12',
        'updated_at': 't',
      });
      final back = Preorder.fromJson(p.toJson())!;
      expect(back.toJson(), p.toJson());
      expect(preordersFrom({'x': 1, 'y': p.toJson()}).keys, ['y']);
    });
  });

  group('UserStore 섹션', () {
    test('조립 · 예약은 items 에 칸을 더하지 않고 local_state 섹션으로 · 비면 키 없음', () {
      final s = UserStore.memory()..setStatus('k1', CollectStatus.owned);
      final before = s.toJson();
      expect((before['local_state']! as Map).containsKey('build_status'), isFalse);
      expect((before['local_state']! as Map).containsKey('preorders'), isFalse);
      s.setBuild('k1', stage: BuildStage.built, painted: true);
      s.putPreorder('k2', const Preorder(shop: '샵', price: 5000, arrival: '2026-12'));
      final j = s.toJson();
      final local = j['local_state']! as Map;
      expect((local['build_status'] as Map)['k1'], containsPair('stage', 'built'));
      expect(((local['build_status'] as Map)['k1'] as Map)['updated_at'], isNotEmpty);
      expect((local['preorders'] as Map)['k2'], containsPair('shop', '샵'));
      // 공유 기록 모양 그대로 (옛 앱이 모르는 칸 없음)
      final item = ((j['collection']! as Map)['items'] as Map)['k1'] as Map;
      expect(item.keys.toSet(), {'status', 'updated_at', 'updated_by', 'quantity'});
      // 다시 읽기
      final r = UserStore.memory()..debugLoadJson(j);
      expect(r.buildOf('k1').stage, BuildStage.built);
      expect(r.buildOf('k1').painted, isTrue);
      expect(r.preorderOf('k2')!.price, 5000);
    });

    test('조립 상태 바꿔도 공유 변경으로 세지 않는다 (서버에 안 올림)', () {
      final s = UserStore.memory();
      final rev = s.sharedRevision;
      s.setBuild('k1', stage: BuildStage.building);
      s.putPreorder('k1', const Preorder(price: 1));
      expect(s.sharedRevision, rev);
      expect(s.cloudDirty, isFalse);
    });

    test('예약 지우기 = deleted 로 남김 · 되살리기', () {
      final s = UserStore.memory()..putPreorder('k', const Preorder(shop: 'a'));
      s.putPreorder('k', null);
      expect(s.preorderOf('k'), isNull);
      expect(s.preorders['k']!.deleted, isTrue);
      expect(s.activePreorders, isEmpty);
      s.putPreorder('k', const Preorder(shop: 'b'));
      expect(s.preorderOf('k')!.shop, 'b');
    });

    test('도착 → 구매함 (예약 총액 = 내 구매가) · 되돌리기', () {
      final s = UserStore.memory()
        ..setStatus('k', CollectStatus.wanted)
        ..putPreorder('k', const Preorder(price: 8800, arrival: '2026-12'));
      final rev = s.sharedRevision;
      final before = s.preorderArrived('k', toOwned: true)!;
      expect(s.statusOf('k'), CollectStatus.owned);
      expect(s.entry('k')!['purchase_price'], 8800);
      expect(s.preorderOf('k'), isNull);
      expect(s.sharedRevision, rev + 1);
      s.undoArrival('k', before);
      expect(s.statusOf('k'), CollectStatus.wanted);
      expect(s.entry('k')!.containsKey('purchase_price'), isFalse);
      expect(s.preorderOf('k')!.active, isTrue);
    });

    test('도착만 → 좋아요 그대로 · 기다리는 예약에서 빠짐', () {
      final s = UserStore.memory()
        ..setStatus('k', CollectStatus.wanted)
        ..putPreorder('k', const Preorder(price: 100));
      s.preorderArrived('k', toOwned: false);
      expect(s.statusOf('k'), CollectStatus.wanted);
      expect(s.preorderOf('k')!.arrivedAt, isNotEmpty);
      expect(s.activePreorders, isEmpty);
    });

    test('다른 계정으로 로그인하면 조립 · 예약도 비운다', () {
      final s = UserStore.memory()
        ..setBuild('k', stage: BuildStage.built)
        ..putPreorder('k', const Preorder());
      s.resetForAccount('other');
      expect(s.buildStatus, isEmpty);
      expect(s.preorders, isEmpty);
    });

    test('알림 설정용 예약 도착 목록 (도착 예정이 있는 기다리는 예약만)', () {
      final s = UserStore.memory()
        ..putPreorder('a', const Preorder(price: 5000, deposit: 1000, arrival: '2026-12', shop: 'PB'))
        ..putPreorder('b', const Preorder());
      final dues = preorderDuesFor(s.activePreorders, {'a': kit('a')});
      expect(dues.single.toJson(), {
        'id': 'a',
        'name': '상품 a',
        'franchise': 'gundam',
        'arrival': '2026-12',
        'due': 4000,
        'shop': 'PB',
      });
    });
  });

  group('바코드 겹침', () {
    test('구매함 > 예약 > 좋아요 · 없으면 null', () {
      final s = UserStore.memory()
        ..setStatus('own', CollectStatus.owned)
        ..setQuantity('own', 2)
        ..setBuild('own', stage: BuildStage.building)
        ..setStatus('pre', CollectStatus.wanted)
        ..putPreorder('pre', const Preorder(shop: 'PB'))
        ..setStatus('like', CollectStatus.wanted);
      CollectStatus st(Kit k) => s.statusOf(k.id) ?? CollectStatus.none;
      expect(scanDuplicate([kit('none')], s, st), isNull);
      expect(scanDuplicate([kit('like')], s, st)!.kind, ScanDupKind.liked);
      expect(scanDuplicate([kit('like'), kit('pre')], s, st)!.kind, ScanDupKind.preorder);
      final d = scanDuplicate([kit('pre'), kit('own'), kit('like')], s, st)!;
      expect(d.kind, ScanDupKind.owned);
      expect(d.kit.id, 'own');
      expect(d.quantity, 2);
      expect(d.build.stage, BuildStage.building);
    });
  });
}
