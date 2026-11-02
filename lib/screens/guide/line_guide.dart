// 옛 G-10 종류별 도감 → 검색 탭 종류 보기(B-20, lib/screens/b_category_browse.dart TypeBrowse)로 옮겼다.
// 검색 화면(b_search_screen.dart)이 아직 이 이름을 부르는 동안만 남겨 두는 다리 — TypeBrowse 로 바꾸면 이 파일을 지운다.
// (찾기 글자 · '내 것만' 은 분류 칸에 숫자를 두지 않으면서 없어졌다: 상품 화면의 필터 · 찾기로)
import 'package:flutter/material.dart';

import '../../api.dart';
import '../../channels.dart';
import '../b_category_browse.dart';

/// [TypeBrowse] 로 넘기는 다리 ([query] · [mineOnly] 는 쓰지 않는다)
class LineGuideView extends StatelessWidget {
  const LineGuideView({
    super.key,
    required this.channel,
    required this.loaders,
    this.query = '',
    this.mineOnly = false,
    this.myChannels,
    this.onPickChannel,
  });

  final String channel;
  final Loaders loaders;
  final String query;
  final bool mineOnly;
  final List<String>? myChannels;
  final ValueChanged<String>? onPickChannel;

  @override
  Widget build(BuildContext context) => TypeBrowse(
    channel: channel,
    loaders: loaders,
    myChannels:
        myChannels ??
        [
          for (final c in allChannels)
            if (c.hasData) c.id,
        ],
    onPickChannel: onPickChannel,
  );
}
