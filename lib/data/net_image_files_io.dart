// 인터넷 그림 받기 — 안드로이드: dart:io 클라이언트 하나를 같이 쓴다 (연결을 다시 쓰고, 답 없는 서버는 8초에 끊는다)
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

http.Client createImageClient() => IOClient(HttpClient()..connectionTimeout = const Duration(seconds: 8));

bool get prefetchOn => Platform.isAndroid;
