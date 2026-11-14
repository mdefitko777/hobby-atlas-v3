// 작품 · 세대 칸의 짧은 이름 — 반복되는 "기동전사 건담" · "포켓몬스터" 머리를 보이는 곳에서만 뺀다 (lib/logic/short_names.dart)
// 이름은 2026-11-14 데이터 그대로 (atlas/gundam-ms.json works[].names · atlas-groups.json franchises.pokemon[].labels)
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/logic/short_names.dart';

void main() {
  test('건담 작품: 머리 빼기 (ko · zh · ja)', () {
    const table = {
      // 첫 작품은 남는 것이 없어 그대로
      '기동전사 건담': '기동전사 건담',
      '机动战士高达': '机动战士高达',
      '機動戦士ガンダム': '機動戦士ガンダム',
      '기동전사 건담 SEED': 'SEED',
      '机动战士高达SEED': 'SEED',
      '기동전사 건담 수성의 마녀': '수성의 마녀',
      '机动战士高达 水星的魔女': '水星的魔女',
      '機動戦士ガンダム 水星の魔女': '水星の魔女',
      '기동전사 건담 디 오리진': '디 오리진',
      '机动战士高达THE ORIGIN': 'THE ORIGIN',
      '기동전사 건담  MS IGLOO': 'MS IGLOO', // 빈칸 둘
      '机动战士高达0080  口袋中的战争': '0080 口袋中的战争',
      '机动战士高达  独角兽': '独角兽',
      '기동전사 건담 UC': 'UC',
      '기동전사 건담 외전 THE BLUE DESTINY': '외전 THE BLUE DESTINY',
      '机动战士高达战记 失落的战争': '战记 失落的战争',
      '기동전사 건담 철혈의 오펀스 월강': '철혈의 오펀스 월강',
      '기동전사 건담 00': '00',
      // 뒤에 건담이 붙는 작품은 "기동전사" 만
      '기동전사 Z건담': 'Z건담',
      '机动战士Z高达': 'Z高达',
      '기동전사 V건담': 'V건담',
      '机动战士Ｖ高达': 'Ｖ高达',
      '기동전사 크로스본 건담': '크로스본 건담',
      '机动战士海盗高达': '海盗高达',
      '기동전사 Gundam GQuuuuuuX': 'Gundam GQuuuuuuX',
      // 머리가 다른 작품은 그대로
      '신기동전기 건담 W': '신기동전기 건담 W',
      '新机动战记高达W': '新机动战记高达W',
      '기동무투전 G건담': '기동무투전 G건담',
      '턴에이 건담': '턴에이 건담',
      '건담 빌드 파이터즈': '건담 빌드 파이터즈',
      'SD건담 GX': 'SD건담 GX',
      'MSV': 'MSV',
    };
    for (final e in table.entries) {
      expect(shortWorkName(e.key), e.value, reason: e.key);
    }
  });

  test('포켓몬 본편 세대: 머리 빼기 (ko · zh) · 공통 굿즈 묶음 · 다른 채널은 그대로', () {
    const table = {
      ('pokemon-gen1', '포켓몬스터 레드·그린'): '레드·그린',
      ('pokemon-gen1', '宝可梦 红·绿'): '红·绿',
      ('pokemon-gen4', '포켓몬스터 DP 디아루가·펄기아'): 'DP 디아루가·펄기아',
      ('pokemon-gen6', '포켓몬스터 X·Y'): 'X·Y',
      ('pokemon-gen7', '精灵宝可梦 太阳·月亮'): '太阳·月亮',
      ('pokemon-gen9', '포켓몬스터 스칼렛·바이올렛'): '스칼렛·바이올렛',
      ('pokemon-gen9', '宝可梦 朱·紫'): '朱·紫',
      ('pokemon-gen2', 'ポケットモンスター 金・銀'): '金・銀',
      ('pokemon-pokemon_general', '여러 세대 포켓몬 굿즈'): '여러 세대 포켓몬 굿즈',
      ('pokemon-pokemon_common', '宝可梦通用周边'): '宝可梦通用周边',
    };
    for (final e in table.entries) {
      expect(shortWorldLabel('pokemon', e.key.$1, e.key.$2), e.value, reason: e.key.$2);
    }
    expect(shortWorldLabel('fate', 'fate-gen1', '포켓몬스터 레드'), '포켓몬스터 레드');
  });
}
