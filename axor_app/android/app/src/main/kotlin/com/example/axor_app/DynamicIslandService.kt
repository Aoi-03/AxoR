package com.example.axor_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaMetadata
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import java.net.URL

/**
 * DynamicIslandService — Native MediaSession & MediaStyle Playback Service
 *
 * Hooks directly into Android's native MediaSession and Notification.MediaStyle.
 * On Honor MagicOS (Honor 90), this automatically triggers the native "Magic Capsule"
 * around the camera punch-hole with zero extra battery drain, no artificial overlays,
 * and seamless AOD / Lock Screen music art and controls.
 */
class DynamicIslandService : Service() {

    companion object {
        const val ACTION_SHOW = "com.example.axor_app.SHOW_ISLAND"
        const val ACTION_UPDATE = "com.example.axor_app.UPDATE_ISLAND"
        const val ACTION_HIDE = "com.example.axor_app.HIDE_ISLAND"

        const val ACTION_PREVIOUS = "com.example.axor_app.ACTION_PREVIOUS"
        const val ACTION_PLAY_PAUSE = "com.example.axor_app.ACTION_PLAY_PAUSE"
        const val ACTION_NEXT = "com.example.axor_app.ACTION_NEXT"

        const val EXTRA_TITLE = "extra_title"
        const val EXTRA_ARTIST = "extra_artist"
        const val EXTRA_IS_PLAYING = "extra_is_playing"
        const val EXTRA_COVER_URL = "extra_cover_url"
        const val EXTRA_POSITION_MS = "extra_position_ms"
        const val EXTRA_DURATION_MS = "extra_duration_ms"

        private const val NOTIFICATION_CHANNEL_ID = "axor_media_channel"
        private const val NOTIFICATION_ID = 9021
    }

    private var currentTitle = "AXOR"
    private var currentArtist = "Music"
    private var isPlaying = true
    private var currentCoverUrl: String? = null
    private var currentPositionMs = 0L
    private var currentDurationMs = 0L
    private var currentArtworkBitmap: Bitmap? = null

    private var mediaSession: MediaSession? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        initMediaSession()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "AXOR Media Playback",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows playback controls, Honor Magic Capsule, and Lock Screen art"
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }
    }

    private fun initMediaSession() {
        try {
            mediaSession = MediaSession(this, "AxoRMediaSession").apply {
                isActive = true
                setCallback(object : MediaSession.Callback() {
                    override fun onPlay() {
                        MainActivity.sendControlAction("playPause")
                    }
                    override fun onPause() {
                        MainActivity.sendControlAction("playPause")
                    }
                    override fun onSkipToNext() {
                        MainActivity.sendControlAction("next")
                    }
                    override fun onSkipToPrevious() {
                        MainActivity.sendControlAction("previous")
                    }
                    override fun onStop() {
                        MainActivity.sendControlAction("playPause")
                    }
                })
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_PREVIOUS -> {
                MainActivity.sendControlAction("previous")
                return START_NOT_STICKY
            }
            ACTION_PLAY_PAUSE -> {
                MainActivity.sendControlAction("playPause")
                return START_NOT_STICKY
            }
            ACTION_NEXT -> {
                MainActivity.sendControlAction("next")
                return START_NOT_STICKY
            }
            ACTION_SHOW -> {
                currentTitle = intent.getStringExtra(EXTRA_TITLE) ?: currentTitle
                currentArtist = intent.getStringExtra(EXTRA_ARTIST) ?: currentArtist
                isPlaying = intent.getBooleanExtra(EXTRA_IS_PLAYING, true)
                currentPositionMs = intent.getLongExtra(EXTRA_POSITION_MS, 0L)
                currentDurationMs = intent.getLongExtra(EXTRA_DURATION_MS, 0L)

                val newCoverUrl = intent.getStringExtra(EXTRA_COVER_URL)
                if (newCoverUrl != null && newCoverUrl != currentCoverUrl) {
                    currentCoverUrl = newCoverUrl
                    loadCoverBitmap(newCoverUrl)
                }

                updateMediaSession()
                postMediaNotification(isForeground = true)
            }
            ACTION_UPDATE -> {
                val title = intent.getStringExtra(EXTRA_TITLE)
                if (title != null) currentTitle = title
                val artist = intent.getStringExtra(EXTRA_ARTIST)
                if (artist != null) currentArtist = artist
                if (intent.hasExtra(EXTRA_IS_PLAYING)) {
                    isPlaying = intent.getBooleanExtra(EXTRA_IS_PLAYING, true)
                }
                if (intent.hasExtra(EXTRA_POSITION_MS)) {
                    currentPositionMs = intent.getLongExtra(EXTRA_POSITION_MS, currentPositionMs)
                }
                if (intent.hasExtra(EXTRA_DURATION_MS)) {
                    currentDurationMs = intent.getLongExtra(EXTRA_DURATION_MS, currentDurationMs)
                }

                val newCoverUrl = intent.getStringExtra(EXTRA_COVER_URL)
                if (newCoverUrl != null && newCoverUrl != currentCoverUrl) {
                    currentCoverUrl = newCoverUrl
                    loadCoverBitmap(newCoverUrl)
                }

                updateMediaSession()
                postMediaNotification(isForeground = false)
            }
            ACTION_HIDE -> {
                cleanupAndStop()
            }
        }
        return START_NOT_STICKY
    }

    private fun updateMediaSession() {
        try {
            val session = mediaSession ?: return
            val metadataBuilder = MediaMetadata.Builder()
                .putString(MediaMetadata.METADATA_KEY_TITLE, currentTitle)
                .putString(MediaMetadata.METADATA_KEY_ARTIST, currentArtist)
                .putString(MediaMetadata.METADATA_KEY_ALBUM, "AXOR")
                .putLong(MediaMetadata.METADATA_KEY_DURATION, currentDurationMs)

            val bmp = currentArtworkBitmap
            if (bmp != null) {
                metadataBuilder.putBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART, bmp)
                metadataBuilder.putBitmap(MediaMetadata.METADATA_KEY_ART, bmp)
            }
            session.setMetadata(metadataBuilder.build())

            val state = if (isPlaying) PlaybackState.STATE_PLAYING else PlaybackState.STATE_PAUSED
            val playbackState = PlaybackState.Builder()
                .setState(state, currentPositionMs, 1.0f)
                .setActions(
                    PlaybackState.ACTION_PLAY or
                    PlaybackState.ACTION_PAUSE or
                    PlaybackState.ACTION_PLAY_PAUSE or
                    PlaybackState.ACTION_SKIP_TO_NEXT or
                    PlaybackState.ACTION_SKIP_TO_PREVIOUS or
                    PlaybackState.ACTION_SEEK_TO or
                    PlaybackState.ACTION_STOP
                )
                .build()
            session.setPlaybackState(playbackState)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun postMediaNotification(isForeground: Boolean) {
        try {
            val session = mediaSession ?: return

            val openAppIntent = PendingIntent.getActivity(
                this,
                0,
                packageManager.getLaunchIntentForPackage(packageName)?.apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val prevIntent = PendingIntent.getService(
                this,
                1,
                Intent(this, DynamicIslandService::class.java).apply { action = ACTION_PREVIOUS },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            val playPauseIntent = PendingIntent.getService(
                this,
                2,
                Intent(this, DynamicIslandService::class.java).apply { action = ACTION_PLAY_PAUSE },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            val nextIntent = PendingIntent.getService(
                this,
                3,
                Intent(this, DynamicIslandService::class.java).apply { action = ACTION_NEXT },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val mediaStyle = Notification.MediaStyle()
                .setMediaSession(session.sessionToken)
                .setShowActionsInCompactView(0, 1, 2)

            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(this, NOTIFICATION_CHANNEL_ID)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(this)
            }

            builder.setStyle(mediaStyle)
                .setContentTitle(currentTitle)
                .setContentText(currentArtist)
                .setSmallIcon(android.R.drawable.ic_media_play)
                .setContentIntent(openAppIntent)
                .setVisibility(Notification.VISIBILITY_PUBLIC)
                .setOngoing(isPlaying)
                .addAction(
                    Notification.Action.Builder(
                        android.R.drawable.ic_media_previous,
                        "Previous",
                        prevIntent
                    ).build()
                )
                .addAction(
                    Notification.Action.Builder(
                        if (isPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play,
                        if (isPlaying) "Pause" else "Play",
                        playPauseIntent
                    ).build()
                )
                .addAction(
                    Notification.Action.Builder(
                        android.R.drawable.ic_media_next,
                        "Next",
                        nextIntent
                    ).build()
                )

            val bmp = currentArtworkBitmap
            if (bmp != null) {
                builder.setLargeIcon(bmp)
            }

            val notification = builder.build()

            if (isForeground) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    startForeground(
                        NOTIFICATION_ID,
                        notification,
                        ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
                    )
                } else {
                    startForeground(NOTIFICATION_ID, notification)
                }
            } else {
                val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                manager.notify(NOTIFICATION_ID, notification)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun loadCoverBitmap(urlStr: String) {
        Thread {
            try {
                val url = URL(urlStr)
                val conn = url.openConnection()
                conn.connectTimeout = 4000
                conn.readTimeout = 4000
                val bmp = BitmapFactory.decodeStream(conn.getInputStream())
                if (bmp != null) {
                    currentArtworkBitmap = bmp
                    mainHandler.post {
                        updateMediaSession()
                        postMediaNotification(isForeground = false)
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }.start()
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        cleanupAndStop()
    }

    private fun cleanupAndStop() {
        try {
            mediaSession?.isActive = false
            mediaSession?.release()
            mediaSession = null
        } catch (e: Exception) {
            e.printStackTrace()
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    override fun onDestroy() {
        cleanupAndStop()
        super.onDestroy()
    }
}
