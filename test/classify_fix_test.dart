// 실제 데이터 점검(2026-11)에서 찾은 분류 어긋남 바로잡기 · 이름 HTML 엔티티
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/data/gunpula.dart';

void main() {
  test('No Grade 안의 옵션 파츠 · 옛 HG · 풀메카닉스 · 하이레조', () {
    expect(correctedCode('NG', 'ビルダーズパーツHD MS ハンド01'), 'OPTION_PARTS');
    expect(correctedCode('NG', 'オプションパーツセット ガンプラ 20 (ライドオンセット)'), 'OPTION_PARTS');
    expect(correctedCode('NG', '1 / 144 HG フリーダムガンダム'), 'HG');
    expect(correctedCode('NG', '1 / 100 フルメカニクス ガンダムバエル'), 'FM');
    expect(correctedCode('NG', '1 / 100 ハイレゾリューションモデル ガンダムバルバトス'), 'HIRM');
    // 진짜 No Grade (옛 1/144) 는 그대로
    expect(correctedCode('NG', '1 / 144 ストライクガンダム'), 'NG');
    expect(lineLabel('OPTION_PARTS', '', 'x'), '옵션 파츠');
    expect(typeLabel('OPTION_PARTS', ''), '프라모델');
  });

  test('Fate: 스케일 안의 미니 · 트레이딩, 굿즈 안의 봉제인형 (가방 · 파우치는 굿즈)', () {
    expect(correctedCode('FATE_SCALE', 'HELLO! GOOD SMILE Saber / Altria Pendragon'), 'FATE_MINI');
    expect(correctedCode('FATE_SCALE', 'Fate / Grand Order Duel -collection figure- Vol.10'), 'FATE_MINI');
    expect(correctedCode('FATE_SCALE', 'セイバー 1/7スケール'), 'FATE_SCALE');
    expect(correctedCode('FATE_GOODS', 'エクスカリバー ぬいぐるみ'), 'FATE_PLUSH');
    expect(correctedCode('FATE_GOODS', 'ぬいぐるみ収納バッグ（全3種）'), 'FATE_GOODS');
    expect(typeLabel('FATE_PLUSH', ''), '인형');
    expect(lineLabel('FATE_MINI', '', 'x'), '미니 · 트레이딩');
  });

  test('피규어 칸의 평면 굿즈 → 굿즈 (실드 · 실더 · ConoFig 는 그대로)', () {
    expect(correctedCode('POKE_FIGURE', '포켓몬센터 아크릴 스탠드 POKÉMON TRAINERS 푸름＆꾸왁스'), 'POKE_GOODS');
    expect(correctedCode('FATE_SCALE', '額装レイヤードアクリルアート（第2部 終章メインビジュアル）'), 'FATE_GOODS');
    expect(correctedCode('FATE_SCALE', 'Fate / Grand Order オリジナルサーヴァントウォッチ シールダー / マシュ・キリエライト モデル'), 'FATE_GOODS');
    expect(correctedCode('BEYBLADE_X', 'BX-00 【アプリ・イベント限定】 ベイブレードステッカー 01'), 'BEYBLADE_GOODS');
    expect(correctedCode('BEYBLADE_X', 'BX-04 ナイトシールド3-80N'), 'BEYBLADE_X');
    expect(correctedCode('FATE_SCALE', 'ConoFig Fate / Grand Order シールダー / マシュ・キリエライト'), 'FATE_SCALE');
    expect(correctedCode('POKE_GASHAPON', 'ポケットモンスター アクリルスタンドvol.1'), 'POKE_GASHAPON'); // 캡슐은 가샤폰 그대로
    expect(lineLabel('BEYBLADE_GOODS', '', 'beyblade-x-bx00-st01'), '굿즈');
    expect(typeLabel('BEYBLADE_GOODS', ''), '굿즈');
  });

  test('이름의 HTML 엔티티', () {
    expect(unescapeHtml('133 ぬいぐるみ Pok&eacute;mon fit イーブイ'), '133 ぬいぐるみ Pokémon fit イーブイ');
    expect(unescapeHtml('A &amp; B &#39;x&#39; &#x2665; &ndash;'), "A & B 'x' ♥ –");
    expect(unescapeHtml('&unknown; 그대로'), '&unknown; 그대로');
  });
}
