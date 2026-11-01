// Hobby Atlas v3 — 개인용 수집 앱 (Gunpula 실제 데이터 · 기기 저장 · Gunpula 계정 동기화)
//
// ┌──────── 디자인 가이드 대응표: 앱 뼈대 ──────────────────────────────────────┐
// │ 번호 │ Flutter 위젯명        │ 비즈니스 명칭(한글)                        │ 원칙(P번호)   │
// │ S-14 │ MaterialApp           │ Hobby Atlas                                │ —             │
// │ S-15 │ buildGpTheme()        │ 흑백 + 파랑(고름) · 민트(가진 것) · 글자 6단계 │ P08 · P04 │
// │ S-16 │ MarksHost · PaneHost  │ 좋아요 · 구매함 / 오른쪽 칸에 연 것 (앱 전체) │ P04 · P01 │
// │ S-17 │ AccountScope          │ 로그인 · 동기화 · 친구 (앱 전체)            │ P01           │
// │ S-18 │ NotifyScope           │ 알림함 · 안 읽은 수 · 알림 설정 (앱 전체)    │ P01           │
// │ S-20 │ FirstRunGate          │ 처음 설치: 데이터 받는 화면(W) → 앱 셸        │ P01           │
// └────────────────────────────────────────────────────────────────────────────┘
import 'package:flutter/material.dart';

import 'data/catalog.dart';
import 'data/user_store.dart';
import 'detail_pane.dart';
import 'marks.dart';
import 'notifications/notify_store.dart';
import 'screens/s_app_shell.dart';
import 'screens/w_first_run_screen.dart';
import 'share/share_intake.dart';
import 'sync/account.dart';
import 'sync/supabase_backend.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final meLoaded = UserStore.instance.load(); // 내 기록 (기기)
  Catalog.instance.ensureLoaded().ignore(); // 캐시 → 뒤에서 새 데이터 확인
  // 계정: Gunpula Supabase (config/supabase.json). 저장된 세션이 있으면 바로 받아 온다.
  final auth = SupabaseAuthService();
  Account.instance = Account(auth: auth, rpc: SupabaseRpc(auth), storage: SupabasePhotoStorage(auth))
    ..start()
    ..sync.attachLifecycle();
  auth.start().ignore();
  // 새 소식 알림: 알림함 읽기 · 휴대폰 알림 준비 · 12시간 확인 등록 · 앱을 열 때 · 돌아올 때 확인
  NotifyStore.instance.start(me: UserStore.instance, meLoaded: meLoaded).ignore();
  // 공유로 받기: 다른 앱의 "공유 → Hobby Atlas" (공유로 켜졌으면 그 사진 · 글을 앱 셸이 연다)
  ShareIntake.instance.start().ignore();
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
      // S-16 앱 전체 한 벌(setState 를 위로): 계정(AccountScope) · 알림(NotifyScope) · 좋아요 · 구매함(MarksHost) · 반반 화면 오른쪽 칸(PaneHost)
      builder: (context, child) => AccountScope(
        account: Account.instance, // S-17
        child: NotifyScope(
          store: NotifyStore.instance, // S-18
          child: MarksHost(child: PaneHost(child: child!)),
        ),
      ),
      // 새 데이터를 받으면 화면들이 다시 불러오도록 셸을 새로 만든다 (하루 한 번쯤).
      // 처음 설치(캐시 없음)면 셸 대신 받는 화면 (V)
      home: FirstRunGate(
        catalog: Catalog.instance,
        builder: (context) => AppShell(key: ValueKey(Catalog.instance.version)),
      ),
    );
  }
}
