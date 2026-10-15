package com.flyinabox.app

import android.annotation.SuppressLint
import android.app.AlertDialog
import android.os.Bundle
import android.view.KeyEvent
import android.view.View
import android.view.WindowManager
import android.webkit.WebChromeClient
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
        web.webViewClient = WebViewClient()
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
            .setMessage("On the computer running the simulation, start it with\n\npython flybox.py --live 8765\n\nand enter that computer's address here (it prints it when it starts).")
            .setView(box)
            .setCancelable(false)
            .setPositiveButton("Watch") { _, _ ->
                var u = box.text.toString().trim()
                if (!u.startsWith("http")) u = "http://$u"
                if (!u.substringAfter("://").contains(":")) u = "$u:8765"
                prefs.edit().putString("url", u).apply()
                web.loadUrl(u)
            }
            .show()
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
