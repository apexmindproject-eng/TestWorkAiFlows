package com.flyinabox.app

import android.annotation.SuppressLint
import android.graphics.Color
import android.graphics.Typeface
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.webkit.WebChromeClient
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.ScrollView
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import java.net.HttpURLConnection
import java.net.URL
import kotlin.concurrent.thread

/** The fly, on this phone: a status screen while the runtime unpacks and the brain loads, then the live page. */
class MainActivity : AppCompatActivity() {
    private lateinit var frame: FrameLayout
    private lateinit var status: LinearLayout
    private lateinit var title: TextView
    private lateinit var detail: TextView
    private lateinit var bar: ProgressBar
    private lateinit var log: TextView
    private lateinit var button: Button
    private var web: WebView? = null
    private val ui = Handler(Looper.getMainLooper())
    private var showingFly = false
    private var lastProbe = 0L

    @SuppressLint("SetTextI18n")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        frame = FrameLayout(this).apply { setBackgroundColor(0xFF0B0B10.toInt()) }
        status = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; setPadding(48, 96, 48, 48) }
        title = TextView(this).apply { text = "Fly in a Box"; textSize = 26f; setTextColor(0xFF8CC8FF.toInt()); typeface = Typeface.DEFAULT_BOLD }
        detail = TextView(this).apply { textSize = 15f; setTextColor(0xFFE8E8F0.toInt()); setPadding(0, 16, 0, 16) }
        bar = ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal).apply { max = 1000; visibility = View.GONE }
        log = TextView(this).apply { textSize = 11f; setTextColor(0xFF99A0B0.toInt()); typeface = Typeface.MONOSPACE; setPadding(0, 24, 0, 0) }
        button = Button(this).apply { text = "Start the fly"; setOnClickListener { onButton() } }
        val hint = TextView(this).apply {
            text = "A real FlyWire brain (138,639 neurons, 15 million synapses) in a NeuroMechFly body, in a box, computed on this phone. " +
                "The first start unpacks about 1.5 GB (a few minutes); every start then loads the brain (about a minute). " +
                "It runs in slow motion: one second of fly time takes one to three minutes here."
            textSize = 13f; setTextColor(0xFF99A0B0.toInt()); setPadding(0, 24, 0, 0)
        }
        status.addView(title); status.addView(detail); status.addView(bar); status.addView(button); status.addView(hint)
        status.addView(ScrollView(this).apply { addView(log) }, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f))
        frame.addView(status)
        setContentView(frame)
        if (FlyService.running || Runtime(this).isUnpacked) FlyService.start(this)
        ui.post(tick)
    }

    private fun onButton() {
        if (FlyService.running) { FlyService.stop(this); showStatus() } else FlyService.start(this)
    }

    private val tick = object : Runnable {
        @SuppressLint("SetTextI18n")
        override fun run() {
            val phase = FlyService.phase
            button.text = if (FlyService.running) "Stop the fly" else "Start the fly"
            detail.text = when (phase) {
                "idle" -> "Not running."
                "unpacking" -> "Unpacking the runtime (one time): ${FlyService.detail}"
                "starting" -> "Starting… ${FlyService.detail}"
                "running" -> "Running. ${FlyService.detail}"
                "failed" -> "It stopped with an error. ${FlyService.detail}"
                else -> FlyService.detail
            }
            bar.visibility = if (phase == "unpacking") View.VISIBLE else View.GONE
            bar.progress = (1000 * FlyService.progress).toInt()
            if (!showingFly) {
                try { val f = Runtime(this@MainActivity).logFile; if (f.exists()) { val lines = f.readLines(); log.text = lines.takeLast(25).joinToString("\n") } } catch (_: Exception) {}
                val now = System.currentTimeMillis()
                if (FlyService.running && now - lastProbe > 3000) { lastProbe = now; probe() }
            } else if (!FlyService.running) showStatus()
            ui.postDelayed(this, 1000)
        }
    }

    /** Is the simulation serving yet? Then switch to its page. */
    private fun probe() = thread {
        try {
            val c = URL("http://127.0.0.1:8765/state").openConnection() as HttpURLConnection
            c.connectTimeout = 1500; c.readTimeout = 1500
            if (c.responseCode == 200) ui.post { showFly() }
            c.disconnect()
        } catch (_: Exception) {}
    }

    @SuppressLint("SetJavaScriptEnabled")
    private fun showFly() {
        if (showingFly) return
        showingFly = true
        val w = WebView(this)
        w.settings.javaScriptEnabled = true; w.settings.domStorageEnabled = true
        w.settings.loadWithOverviewMode = true; w.settings.useWideViewPort = true
        w.webViewClient = WebViewClient(); w.webChromeClient = WebChromeClient()
        w.setBackgroundColor(0xFF0B0B10.toInt())
        frame.removeAllViews(); frame.addView(w)
        web = w
        w.loadUrl("http://127.0.0.1:8765/")
    }

    private fun showStatus() {
        if (!showingFly) return
        showingFly = false
        web?.destroy(); web = null
        frame.removeAllViews(); frame.addView(status)
    }

    /** Back on the live page: back to the status screen (the fly keeps running); back there: leave. */
    override fun onBackPressed() {
        if (showingFly) showStatus() else super.onBackPressed()
    }
}
