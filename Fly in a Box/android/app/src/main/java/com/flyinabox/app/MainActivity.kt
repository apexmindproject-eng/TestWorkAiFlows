package com.flyinabox.app

import android.annotation.SuppressLint
import android.app.AlertDialog
import android.os.Bundle
import android.view.KeyEvent
import android.view.View
import android.view.WindowManager
import android.webkit.JavascriptInterface
import android.webkit.WebChromeClient
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.EditText
import androidx.appcompat.app.AppCompatActivity

/** A window onto the simulation: the phone shows the page the simulation serves (flybox.py --live PORT). */
class MainActivity : AppCompatActivity() {
    private lateinit var web: WebView
    private val prefs by lazy { getSharedPreferences("fly", MODE_PRIVATE) }

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        web = WebView(this)
        web.settings.javaScriptEnabled = true
        web.settings.domStorageEnabled = true
        web.settings.mediaPlaybackRequiresUserGesture = false
        web.settings.loadWithOverviewMode = true
        web.settings.useWideViewPort = true
        web.webViewClient = object : WebViewClient() {
            /** Nothing answers yet (the simulation is not started): show our own page, which keeps checking. */
            override fun onReceivedError(view: WebView, request: WebResourceRequest, error: WebResourceError) {
                if (request.isForMainFrame) {
                    val target = request.url.toString()
                    view.loadUrl("file:///android_asset/waiting.html#" + java.net.URLEncoder.encode(target, "UTF-8").replace("+", "%20"))
                }
            }
        }
        web.addJavascriptInterface(object { @JavascriptInterface fun changeServer() { runOnUiThread { askForServer() } } }, "Android")
        web.settings.allowFileAccess = true
        web.webChromeClient = WebChromeClient()
        web.setBackgroundColor(0xFF0B0B10.toInt())
        setContentView(web)
        window.decorView.systemUiVisibility = View.SYSTEM_UI_FLAG_FULLSCREEN or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
        val url = prefs.getString("url", null)
        if (url == null) askForServer() else web.loadUrl(url)
    }

    private fun askForServer() {
        val box = EditText(this)
        box.hint = "http://192.168.1.20:8765"
        box.setText(prefs.getString("url", "http://"))
        AlertDialog.Builder(this)
            .setTitle("Where is the fly?")
            .setMessage("On this phone: install it with Termux (phone/README.md in the project) and start it with  bash ~/fly.sh.\n\nOn a computer: start it there with  python flybox.py --live 8765  and enter that computer's address below.")
            .setView(box)
            .setCancelable(false)
            .setNeutralButton("This phone") { _, _ -> go("http://127.0.0.1:8765") }
            .setPositiveButton("That address") { _, _ ->
                var u = box.text.toString().trim()
                if (!u.startsWith("http")) u = "http://$u"
                if (!u.substringAfter("://").contains(":")) u = "$u:8765"
                go(u)
            }
            .show()
    }

    private fun go(u: String) {
        prefs.edit().putString("url", u).apply()
        web.loadUrl(u)
    }

    /** Long-press the back key to change the server address. */
    override fun onKeyLongPress(keyCode: Int, event: KeyEvent?): Boolean {
        if (keyCode == KeyEvent.KEYCODE_BACK) { askForServer(); return true }
        return super.onKeyLongPress(keyCode, event)
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (keyCode == KeyEvent.KEYCODE_BACK) { event?.startTracking(); return true }
        return super.onKeyDown(keyCode, event)
    }

    override fun onKeyUp(keyCode: Int, event: KeyEvent?): Boolean {
        if (keyCode == KeyEvent.KEYCODE_BACK && event?.isTracking == true && !event.isCanceled) { web.reload(); return true }
        return super.onKeyUp(keyCode, event)
    }
}
