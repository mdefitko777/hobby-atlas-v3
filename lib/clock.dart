// 앱의 "오늘". 테스트 · 스크린샷은 [fixedNow] 를 정해 둔다 (테스트 데이터 test/fixtures/sample-db.json 이 2026-10-25 기준).
DateTime? fixedNow;

DateTime appNow() => fixedNow ?? DateTime.now();
