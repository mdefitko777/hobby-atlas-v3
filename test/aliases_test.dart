// Gunpula 가 합친 kit_id — 내 기록이 남은 id 로 옮겨지고 옛 id 는 '지움'으로 남는지
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/data/user_store.dart';
import 'package:hobby_atlas/models.dart';

void main() {
  test('합쳐진 id 의 구매함 기록이 남은 id 로 옮겨진다', () {
    final s = UserStore.memory()
      ..setStatus('pbandai-old', CollectStatus.owned)
      ..setDetails('pbandai-old', purchasePrice: 3300);
    s.applyAliases({'pbandai-old': 'hg-new'});
    expect(s.statusOf('hg-new'), CollectStatus.owned);
    expect(s.entry('hg-new')?['purchase_price'], 3300);
    expect(s.entry('pbandai-old')?['status'], 'deleted');
  });

  test('남은 id 에 더 새 기록이 있으면 그것을 지킨다', () {
    final s = UserStore.memory()..setStatus('old', CollectStatus.wanted);
    s.setStatus('new', CollectStatus.owned); // 나중에 바꿈
    s.applyAliases({'old': 'new'});
    expect(s.statusOf('new'), CollectStatus.owned);
    expect(s.statusOf('old'), CollectStatus.none);
  });

  test('다시 돌려도 그대로 (지운 기록은 건너뜀)', () {
    final s = UserStore.memory()..setStatus('old', CollectStatus.owned);
    s.applyAliases({'old': 'new'});
    final rev = s.revision;
    s.applyAliases({'old': 'new'});
    expect(s.revision, rev);
  });
}
