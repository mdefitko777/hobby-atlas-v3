# R8 규칙 — 릴리스 빌드에서 줄이기 · 난독화할 때
# ML Kit 글자 인식(google_mlkit_text_recognition): 플러그인이 모든 글자 모델을 가리키지만 앱은 라틴 · 일본어 · 한국어만 넣는다.
# 넣지 않은 중국어 · 데바나가리 모델 클래스는 없어도 된다 (그 모델을 고르지 않는다).
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
