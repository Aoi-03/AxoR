package com.example.axor_app

import android.app.WallpaperManager
import android.content.Intent
import android.graphics.BitmapFactory
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.net.URL

class MainActivity : FlutterActivity() {

    companion object {
        const val CHANNEL = "com.example.axor_app/dynamic_island"
        var instance: MainActivity? = null
        var methodChannel: MethodChannel? = null

        fun sendControlAction(action: String) {
            instance?.runOnUiThread {
                methodChannel?.invokeMethod("onControlAction", action)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        instance = this
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel = channel

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "checkPermission" -> {
                    // Native MediaSession & Honor Magic Capsule require no overlay permissions!
                    result.success(true)
                }
                "requestPermission" -> {
                    result.success(true)
                }
                "showIsland" -> {
                    val title = call.argument<String>("title") ?: "AXOR"
                    val artist = call.argument<String>("artist") ?: "Music"
                    val isPlaying = call.argument<Boolean>("isPlaying") ?: true
                    val coverUrl = call.argument<String>("coverUrl")
                    val positionMs = (call.argument<Int>("positionMs") ?: 0).toLong()
                    val durationMs = (call.argument<Int>("durationMs") ?: 0).toLong()

                    try {
                        val intent = Intent(this, DynamicIslandService::class.java).apply {
                            action = DynamicIslandService.ACTION_SHOW
                            putExtra(DynamicIslandService.EXTRA_TITLE, title)
                            putExtra(DynamicIslandService.EXTRA_ARTIST, artist)
                            putExtra(DynamicIslandService.EXTRA_IS_PLAYING, isPlaying)
                            if (coverUrl != null) putExtra(DynamicIslandService.EXTRA_COVER_URL, coverUrl)
                            putExtra(DynamicIslandService.EXTRA_POSITION_MS, positionMs)
                            putExtra(DynamicIslandService.EXTRA_DURATION_MS, durationMs)
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                    result.success(true)
                }
                "updateIsland" -> {
                    val title = call.argument<String>("title")
                    val artist = call.argument<String>("artist")
                    val isPlaying = call.argument<Boolean>("isPlaying") ?: true
                    val coverUrl = call.argument<String>("coverUrl")
                    val positionMs = (call.argument<Int>("positionMs") ?: 0).toLong()
                    val durationMs = (call.argument<Int>("durationMs") ?: 0).toLong()

                    try {
                        val intent = Intent(this, DynamicIslandService::class.java).apply {
                            action = DynamicIslandService.ACTION_UPDATE
                            if (title != null) putExtra(DynamicIslandService.EXTRA_TITLE, title)
                            if (artist != null) putExtra(DynamicIslandService.EXTRA_ARTIST, artist)
                            putExtra(DynamicIslandService.EXTRA_IS_PLAYING, isPlaying)
                            if (coverUrl != null) putExtra(DynamicIslandService.EXTRA_COVER_URL, coverUrl)
                            putExtra(DynamicIslandService.EXTRA_POSITION_MS, positionMs)
                            putExtra(DynamicIslandService.EXTRA_DURATION_MS, durationMs)
                        }
                        startService(intent)
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                    result.success(true)
                }
                "hideIsland" -> {
                    try {
                        val intent = Intent(this, DynamicIslandService::class.java).apply {
                            action = DynamicIslandService.ACTION_HIDE
                        }
                        startService(intent)
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                    result.success(true)
                }
                "setLockscreenWallpaper" -> {
                    val coverUrl = call.argument<String>("coverUrl")
                    if (coverUrl != null) {
                        Thread {
                            try {
                                val url = URL(coverUrl)
                                val connection = url.openConnection()
                                connection.connectTimeout = 4000
                                connection.readTimeout = 4000
                                val bitmap = BitmapFactory.decodeStream(connection.getInputStream())
                                if (bitmap != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                                    val wm = WallpaperManager.getInstance(this)
                                    wm.setBitmap(bitmap, null, true, WallpaperManager.FLAG_LOCK)
                                }
                            } catch (e: Exception) {
                                e.printStackTrace()
                            }
                        }.start()
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        if (instance == this) {
            instance = null
            methodChannel = null
        }
        super.onDestroy()
    }
}
