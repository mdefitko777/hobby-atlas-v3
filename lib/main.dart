// Hobby Atlas v3 — 개인용 수집 앱 (Gunpula 실제 데이터 · 기기 저장)
//
// ┌──────── 디자인 가이드 대응표: 앱 뼈대 ──────────────────────────────────────┐
// │ 번호 │ Flutter 위젯명        │ 비즈니스 명칭(한글)                        │ 원칙(P번호)   │
// │ S-14 │ MaterialApp           │ Hobby Atlas                                │ —             │
// │ S-15 │ buildGpTheme()        │ 흑백 + 파랑(고름) · 민트(가진 것) · 글자 6단계 │ P08 · P04 │
// │ S-16 │ MarksHost · PaneHost  │ 좋아요 · 구매함 / 오른쪽 칸에 연 것 (앱 전체) │ P04 · P01 │
// └────────────────────────────────────────────────────────────────────────────┘
import 'package:flutter/material.dart';

import 'data/catalog.dart';
import 'data/user_store.dart';
import 'detail_pane.dart';
import 'marks.dart';
import 'notifications/notify_store.dart';
import 'screens/s_app_shell.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final meLoaded = UserStore.instance.load(); // 내 기록 (기기)
  Catalog.instance.ensureLoaded().ignore(); // 캐시 → 뒤에서 새 데이터 확인
  // 새 소식 알림: 알림함 읽기 · 휴대폰 알림 준비 · 12시간 확인 등록 · 앱을 열 때 · 돌아올 때 확인
  NotifyStore.instance.start(me: UserStore.instance, meLoaded: meLoaded).ignore();
  runApp(const HobbyAtlasApp());
}

class HobbyAtlasApp extends StatelessWidget {
  const HobbyAtlasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hobby Atlas', // S-14
      debugShowCheckedModeBanner: false,
      theme: buildGpTheme(), // S-15 P08
      // S-16 앱 전체 한 벌(setState 를 위로): 좋아요 · 구매함(MarksHost) · 반반 화면 오른쪽 칸에 연 것(PaneHost)
      builder: (context, child) => MarksHost(child: PaneHost(child: child!)),
      // 새 데이터를 받으면 화면들이 다시 불러오도록 셸을 새로 만든다 (하루 한 번쯤)
      home: ListenableBuilder(
        listenable: Catalog.instance,
        builder: (context, _) => AppShell(key: ValueKey(Catalog.instance.version)),
      ),
    );
  }
}
