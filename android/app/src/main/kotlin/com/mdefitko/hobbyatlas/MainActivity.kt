package com.mdefitko.hobbyatlas

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

// 공유로 받기 (lib/share/share_intake.dart): 다른 앱의 "공유 → Hobby Atlas" 로 온 사진 · 글, 상품 링크(VIEW)를 Flutter 로 넘긴다.
// 사진은 앱 캐시(shared/)에 복사해 경로로, 글은 제목 + 본문 그대로.
// 공유로 켜졌으면 Flutter 가 "initial" 로 꺼내 가고, 켜져 있을 때 온 공유는 "shared" 로 보낸다 (launchMode singleTask).
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var pending: Map<String, String>? = null

    /** 앱이 꺼졌다 되살아났거나(저장된 상태) 최근 앱 목록에서 다시 열었다 → 처음 켠 intent 는 이미 처리한 것 */
    private var restored = false

    override fun onCreate(savedInstanceState: Bundle?) {
        // super.onCreate 안에서 configureFlutterEngine 을 부르니 그 전에 정한다.
        // 시스템은 되살릴 때 처음 받은 intent(VIEW · SEND)를 다시 준다 — setIntent 는 이 프로세스 안에서만 바뀐다
        restored = savedInstanceState != null ||
            (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY) != 0
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // 되살아난 때는 예전 링크 · 공유를 다시 열지 않는다 (새 링크 · 공유는 onNewIntent 로 온다)
        pending = if (restored) null else readShare(intent)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hobbyatlas/share").also { ch ->
            ch.setMethodCallHandler { call, result ->
                when (call.method) {
                    "initial" -> {
                        result.success(pending)
                        pending = null
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val item = readShare(intent) ?: return
        channel?.invokeMethod("shared", item)
    }

    /** 공유 intent → {type: image, path} · {type: text, text} · 상품 링크 {type: kit, id}. 아니면 null */
    private fun readShare(intent: Intent?): Map<String, String>? {
        if (intent == null) return null
        val action = intent.action ?: return null
        if (action == Intent.ACTION_VIEW) {
            val id = kitIdOf(intent.data)
            setIntent(Intent(Intent.ACTION_MAIN))
            return id?.let { mapOf("type" to "kit", "id" to it) }
        }
        if (action != Intent.ACTION_SEND && action != Intent.ACTION_SEND_MULTIPLE) return null
        val type = intent.type ?: ""
        val item: Map<String, String>? = if (type.startsWith("image/")) {
            firstStream(intent, action)?.let { copyToCache(it) }?.let { mapOf("type" to "image", "path" to it) }
        } else {
            val text = listOfNotNull(
                intent.getStringExtra(Intent.EXTRA_SUBJECT),
                intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString(),
            ).joinToString("\n").trim()
            if (text.isEmpty()) null else mapOf("type" to "text", "text" to text)
        }
        // 같은 공유를 다시 열지 않게 (화면 회전 · 다시 그리기)
        setIntent(Intent(Intent.ACTION_MAIN))
        return item
    }

    /** hobbyatlas://kit/<id> · https://mdefitko777.github.io/Gunpula/app/open.html?kit=<id> → id */
    private fun kitIdOf(uri: Uri?): String? {
        if (uri == null) return null
        val id = when (uri.scheme) {
            "hobbyatlas" -> if (uri.host == "kit") uri.pathSegments.firstOrNull() else null
            "https" -> if (uri.host == "mdefitko777.github.io") uri.getQueryParameter("kit") else null
            else -> null
        }
        return id?.takeIf { Regex("^[A-Za-z0-9][A-Za-z0-9._-]{0,159}$").matches(it) }
    }

    @Suppress("DEPRECATION")
    private fun firstStream(intent: Intent, action: String): Uri? =
        if (action == Intent.ACTION_SEND) {
            if (Build.VERSION.SDK_INT >= 33) intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
            else intent.getParcelableExtra(Intent.EXTRA_STREAM)
        } else {
            val list = if (Build.VERSION.SDK_INT >= 33) intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
            else intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
            list?.firstOrNull()
        }

    /** 다른 앱의 사진을 앱 캐시로 복사 (Flutter 가 읽은 뒤 지운다) */
    private fun copyToCache(uri: Uri): String? = try {
        val dir = File(cacheDir, "shared").apply { mkdirs() }
        val out = File(dir, "share_${System.currentTimeMillis()}.img")
        val input = contentResolver.openInputStream(uri)
        if (input == null) {
            null
        } else {
            input.use { src -> out.outputStream().use { src.copyTo(it) } }
            out.absolutePath
        }
    } catch (e: Exception) {
        null
    }
}
