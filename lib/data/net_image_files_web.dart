// 인터넷 그림 받기 — 웹(미리보기): 브라우저 클라이언트, 미리 받기 없음
import 'package:http/http.dart' as http;

http.Client createImageClient() => http.Client();

bool get prefetchOn => false;
