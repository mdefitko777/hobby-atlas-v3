import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/data/gunpula.dart';

void main() {
  test('raw 로 받은 파일의 보관 사진 경로는 raw 주소로, 다른 ./assets 는 그대로', () {
    const json =
        '{"a":"./assets/catalog/fate/x.jpg","b":"./assets/kotobukiya-ac/y.jpg",'
        '"c":"./assets/bbx/z.png","d":"./assets/atlas/covers/k.jpg","e":"https://x.example/./assets/catalog/q.jpg"}';
    final out = rawAssetPaths(json);
    expect(out, contains('"${gunpulaRawBase}app/assets/catalog/fate/x.jpg"'));
    expect(out, contains('"${gunpulaRawBase}app/assets/kotobukiya-ac/y.jpg"'));
    expect(out, contains('"${gunpulaRawBase}app/assets/bbx/z.png"'));
    expect(out, contains('"./assets/atlas/covers/k.jpg"'), reason: 'Pages 에 남아 있는 폴더');
    expect(out, contains('"https://x.example/./assets/catalog/q.jpg"'));
    expect(resolveAsset('${gunpulaRawBase}app/assets/bbx/z.png'), '${gunpulaRawBase}app/assets/bbx/z.png');
  });
}
