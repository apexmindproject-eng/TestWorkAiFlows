package com.flyinabox.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.IBinder
import android.os.PowerManager
import java.io.File
import kotlin.concurrent.thread

/**
 * Keeps the fly alive: unpacks the runtime on first use, then runs the simulation as a child process while a
 * foreground notification keeps Android from killing it. State is published through static fields the activity polls.
 */
class FlyService : Service() {
    companion object {
        const val ACTION_START = "start"; const val ACTION_STOP = "stop"
        @Volatile var phase = "idle"            // idle | unpacking | starting | running | stopped | failed
        @Volatile var progress = 0f             // unpack progress 0..1
        @Volatile var detail = ""
        @Volatile var running = false
        private var process: Process? = null
        private var worker: Thread? = null
        fun start(ctx: Context) { ctx.startForegroundService(Intent(ctx, FlyService::class.java).setAction(ACTION_START)) }
        fun stop(ctx: Context) { ctx.startService(Intent(ctx, FlyService::class.java).setAction(ACTION_STOP)) }
    }
    private var wake: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(1, note("Fly in a Box", "starting"))
        when (intent?.action) {
            ACTION_STOP -> { stopFly(); stopForeground(true); stopSelf() }
            else -> if (worker?.isAlive != true) startFly()
        }
        return START_STICKY
    }

    private fun startFly() {
        running = true
        wake = (getSystemService(POWER_SERVICE) as PowerManager).newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "fly:sim").also { it.acquire() }
        worker = thread(name = "fly") {
            val rt = Runtime(this)
            try {
                if (!rt.isUnpacked) {
                    phase = "unpacking"; detail = "Unpacking the fly's runtime (once; about 1.5 GB)"
                    rt.unpack { done, total, path -> progress = if (total > 0) done.toFloat() / total else 0f; detail = path
                        update("Unpacking the fly (one time)", "${(100 * progress).toInt()} %") }
                }
                phase = "starting"; detail = "Loading the brain (138,639 neurons)…"; update("Fly in a Box", "loading the brain")
                rt.logFile.writeText("")
                val threads = Runtime.getRuntime().availableProcessors().coerceIn(2, 4)
                val p = rt.launch(threads); process = p
                p.inputStream.bufferedReader().useLines { lines ->
                    rt.logFile.bufferedWriter().use { w ->
                        for (line in lines) {
                            w.write(line); w.newLine(); w.flush()
                            if (line.contains("[live] sandbox at")) { phase = "running"; detail = "running"; update("Fly in a Box", "the fly is alive") }
                            if (line.startsWith("  t=")) detail = line.substring(0, minOf(line.length, 60))
                        }
                    }
                }
                val code = p.waitFor()
                phase = if (code == 0) "stopped" else "failed"; detail = "the simulation ended (exit $code)"
            } catch (e: Throwable) {
                phase = "failed"; detail = e.toString()
                try { rt.logFile.appendText("\n[app] $e\n") } catch (_: Exception) {}
            } finally {
                running = false
                try { wake?.release() } catch (_: Exception) {}
            }
        }
    }

    private fun stopFly() {
        running = false
        process?.destroyForcibly(); process = null
        phase = "stopped"; detail = "stopped"
    }

    override fun onDestroy() { stopFly(); super.onDestroy() }

    private fun update(title: String, text: String) {
        (getSystemService(NOTIFICATION_SERVICE) as NotificationManager).notify(1, note(title, text))
    }

    private fun note(title: String, text: String): Notification {
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        if (nm.getNotificationChannel("fly") == null) nm.createNotificationChannel(NotificationChannel("fly", "Fly in a Box", NotificationManager.IMPORTANCE_LOW))
        val open = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE)
        return Notification.Builder(this, "fly").setContentTitle(title).setContentText(text).setSmallIcon(R.drawable.ic_fly).setContentIntent(open).setOngoing(true).build()
    }
}
