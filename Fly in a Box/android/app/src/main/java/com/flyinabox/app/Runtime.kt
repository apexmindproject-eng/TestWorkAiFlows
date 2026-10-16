package com.flyinabox.app

import android.content.Context
import android.os.Build
import android.system.Os
import org.apache.commons.compress.archivers.tar.TarArchiveEntry
import org.apache.commons.compress.archivers.tar.TarArchiveInputStream
import java.io.BufferedInputStream
import java.io.File
import java.io.FileOutputStream
import java.util.zip.GZIPInputStream

/**
 * The fly's Linux runtime: an Ubuntu file tree with Python, MuJoCo, numba, flygym, the FlyWire brain and the
 * project, carried inside the APK (assets/runtime.tar.gz) and unpacked once into the app's own storage.
 * It is executed through the runtime's own glibc loader, so nothing is installed on the phone and no root is used.
 * Mirrors phone/run_relocated.sh, which tests the same tree on a Linux machine.
 */
class Runtime(private val ctx: Context) {
    val root: File = File(ctx.filesDir, "rt")
    val logFile: File = File(ctx.filesDir, "fly.log")
    private val marker = File(root, ".unpacked")
    val isUnpacked get() = marker.exists()

    private val arm = Build.SUPPORTED_ABIS.firstOrNull()?.startsWith("arm64") == true
    private val triple get() = if (arm) "aarch64-linux-gnu" else "x86_64-linux-gnu"
    private val loader get() = if (arm) File(root, "lib/aarch64-linux-gnu/ld-linux-aarch64.so.1") else File(root, "lib/x86_64-linux-gnu/ld-linux-x86-64.so.2")

    /** Unpack assets/runtime.tar.gz into root. progress(bytesRead, totalBytes, lastPath). */
    fun unpack(progress: (Long, Long, String) -> Unit) {
        if (root.exists()) root.deleteRecursively()
        root.mkdirs()
        val fd = ctx.assets.openFd("runtime.tar.gz")
        val total = fd.length
        val counting = CountingInputStream(fd.createInputStream())
        val links = ArrayList<Pair<File, String>>()
        TarArchiveInputStream(GZIPInputStream(BufferedInputStream(counting, 1 shl 20), 1 shl 16)).use { tar ->
            var n = 0
            while (true) {
                val e: TarArchiveEntry = tar.nextTarEntry ?: break
                val name = e.name.removePrefix("./").trimEnd('/')
                if (name.isEmpty() || name.split('/').any { it == ".." }) continue
                if (name == "dev" || name.startsWith("dev/") || name.startsWith("proc/") || name.startsWith("sys/")) continue
                val f = File(root, name)
                when {
                    e.isDirectory -> f.mkdirs()
                    e.isSymbolicLink -> { f.parentFile?.mkdirs(); links.add(f to e.linkName) }
                    e.isLink -> { f.parentFile?.mkdirs(); val src = File(root, e.linkName.removePrefix("./")); if (src.isFile) src.copyTo(f, overwrite = true) }
                    e.isFile -> {
                        f.parentFile?.mkdirs()
                        FileOutputStream(f).use { out -> tar.copyTo(out, 1 shl 16) }
                        try { Os.chmod(f.path, (e.mode and 0x1FF) or 0x180) } catch (_: Exception) {}   // keep x bits, make sure the owner can read and write
                    }
                    else -> {}   // devices, fifos: not needed
                }
                if (++n % 200 == 0) progress(counting.count, total, name)
            }
        }
        // symlinks last, and absolute ones made relative to the tree (they would otherwise point at the phone's /lib)
        for ((f, target) in links) {
            try { if (f.exists() || isBrokenLink(f)) f.delete() } catch (_: Exception) {}
            val t = if (target.startsWith("/")) relativeTo(f.parentFile!!, File(root, target.removePrefix("/"))) else target
            try { Os.symlink(t, f.path) } catch (_: Exception) {}
        }
        progress(total, total, "done")
        File(root, "tmp").mkdirs()
        marker.writeText(Build.SUPPORTED_ABIS.joinToString(","))
    }

    private fun isBrokenLink(f: File) = try { Os.lstat(f.path); !f.exists() } catch (_: Exception) { false }

    private fun relativeTo(fromDir: File, target: File): String {
        val from = fromDir.canonicalFile.toPath(); val to = target.toPath()
        return try { from.relativize(to).toString() } catch (_: Exception) { target.path }
    }

    /** Start the simulation: python flybox.py --live 8765 --phone, through the loader, output to fly.log. */
    fun launch(threads: Int): Process {
        val pyDir = File(root, "usr/lib").listFiles { d -> d.name.startsWith("python3.") }?.firstOrNull() ?: error("no python in the runtime")
        val pyver = pyDir.name
        val libPath = listOf("lib/$triple", "usr/lib/$triple", "lib", "usr/lib").joinToString(":") { File(root, it).path }
        val app = File(root, "opt/fly/app")
        File(root, "tmp/numba").mkdirs(); File(app, "out").mkdirs()
        val cmd = listOf(loader.path, "--library-path", libPath, File(root, "usr/bin/$pyver").path,
            "flybox.py", "--live", "8765", "--phone", "--out", "out/phone")
        val pb = ProcessBuilder(cmd).directory(app).redirectErrorStream(true)
        val env = pb.environment()
        env.clear()
        env["PATH"] = File(root, "usr/bin").path + ":" + File(root, "bin").path
        env["LD_LIBRARY_PATH"] = libPath
        env["PYTHONHOME"] = File(root, "usr").path
        env["PYTHONPATH"] = File(root, "opt/fly/venv/lib/$pyver/site-packages").path
        env["PYTHONNOUSERSITE"] = "1"; env["PYTHONUNBUFFERED"] = "1"
        env["HOME"] = File(root, "root").path; env["TMPDIR"] = File(root, "tmp").path
        env["MUJOCO_GL"] = "osmesa"; env["PYOPENGL_PLATFORM"] = "osmesa"; env["LC_ALL"] = "C.UTF-8"
        env["NUMBA_CACHE_DIR"] = File(root, "tmp/numba").path
        env["OMP_NUM_THREADS"] = threads.toString(); env["NUMBA_NUM_THREADS"] = threads.toString(); env["OPENBLAS_NUM_THREADS"] = "1"
        return pb.start()
    }

    /** A stream that counts what passes through it (for the unpack progress). */
    private class CountingInputStream(private val inner: java.io.InputStream) : java.io.InputStream() {
        var count = 0L
        override fun read(): Int { val b = inner.read(); if (b >= 0) count++; return b }
        override fun read(b: ByteArray, off: Int, len: Int): Int { val n = inner.read(b, off, len); if (n > 0) count += n; return n }
        override fun close() = inner.close()
    }
}
