// 기기 안에 글자 파일을 남기는 곳 (상품 캐시 · 내 수집 기록).
// 안드로이드: 앱 전용 폴더의 파일 / 웹(미리보기): localStorage (용량을 넘으면 저장하지 않는다)
export 'blob_store_io.dart' if (dart.library.js_interop) 'blob_store_web.dart';
