package com.example.axor_app

import android.animation.ValueAnimator
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.*
import android.graphics.drawable.GradientDrawable
import android.media.MediaMetadata
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.view.animation.LinearInterpolator
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import java.net.URL

class DynamicIslandService : Service() {

    companion object {
        const val ACTION_SHOW = "com.example.axor_app.SHOW_ISLAND"
        const val ACTION_UPDATE = "com.example.axor_app.UPDATE_ISLAND"
        const val ACTION_HIDE = "com.example.axor_app.HIDE_ISLAND"

        const val EXTRA_TITLE = "extra_title"
        const val EXTRA_ARTIST = "extra_artist"
        const val EXTRA_IS_PLAYING = "extra_is_playing"
        const val EXTRA_COVER_URL = "extra_cover_url"
        const val EXTRA_POSITION_MS = "extra_position_ms"
        const val EXTRA_DURATION_MS = "extra_duration_ms"

        private const val NOTIFICATION_CHANNEL_ID = "axor_island_channel"
        private const val NOTIFICATION_ID = 9021
    }

    private var windowManager: WindowManager? = null
    private var islandRootView: FrameLayout? = null
    private var windowParams: WindowManager.LayoutParams? = null

    // State
    private var isExpanded = false
    private var currentTitle = "AXOR"
    private var currentArtist = "Music"
    private var isPlaying = true
    private var currentCoverUrl: String? = null
    private var currentPositionMs = 0L
    private var currentDurationMs = 0L
    private var currentArtworkBitmap: Bitmap? = null

    // Views
    private var compactWaveform: WaveformBarsView? = null
    private var compactArtView: ImageView? = null
    private var expandedArtView: ImageView? = null
    private var expandedTitleView: TextView? = null
    private var expandedArtistView: TextView? = null
    private var expandedPosView: TextView? = null
    private var expandedDurView: TextView? = null
    private var expandedProgressBar: ProgressBar? = null
    private var expandedPlayPauseBtn: ImageView? = null

    // Auto-collapse handler
    private val mainHandler = Handler(Looper.getMainLooper())
    private val collapseRunnable = Runnable {
        if (isExpanded) {
            collapseIsland()
        }
    }

    // MediaSession for Lock Screen & AOD Music Art
    private var mediaSession: MediaSession? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        initMediaSession()
        startForegroundServiceNotification()
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
                })
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun updateMediaSession() {
        try {
            val session = mediaSession ?: return
            val metadataBuilder = MediaMetadata.Builder()
                .putString(MediaMetadata.METADATA_KEY_TITLE, currentTitle)
                .putString(MediaMetadata.METADATA_KEY_ARTIST, currentArtist)
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
                    PlaybackState.ACTION_SKIP_TO_NEXT or
                    PlaybackState.ACTION_SKIP_TO_PREVIOUS or
                    PlaybackState.ACTION_SEEK_TO
                )
                .build()
            session.setPlaybackState(playbackState)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun startForegroundServiceNotification() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                val channel = NotificationChannel(
                    NOTIFICATION_CHANNEL_ID,
                    "AXOR Dynamic Island",
                    NotificationManager.IMPORTANCE_LOW
                ).apply {
                    description = "Keeps the Dynamic Island overlay active during playback"
                    setShowBadge(false)
                }
                val manager = getSystemService(NotificationManager::class.java)
                manager?.createNotificationChannel(channel)

                val notification = Notification.Builder(this, NOTIFICATION_CHANNEL_ID)
                    .setContentTitle(currentTitle)
                    .setContentText(currentArtist)
                    .setSmallIcon(android.R.drawable.ic_media_play)
                    .build()

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    startForeground(
                        NOTIFICATION_ID,
                        notification,
                        android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
                    )
                } else {
                    startForeground(NOTIFICATION_ID, notification)
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!Settings.canDrawOverlays(this)) {
            stopSelf()
            return START_NOT_STICKY
        }

        when (intent?.action) {
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

                showOrUpdateIsland()
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

                updateIslandViews()
            }
            ACTION_HIDE -> {
                hideIsland()
                stopSelf()
            }
        }
        return START_NOT_STICKY
    }

    // ── Task Removed (User swipes AxoR from background / Recents) ──
    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        hideIsland()
        stopSelf()
    }

    private fun loadCoverBitmap(urlStr: String) {
        Thread {
            try {
                val url = URL(urlStr)
                val conn = url.openConnection()
                conn.connectTimeout = 3000
                conn.readTimeout = 3000
                val bmp = BitmapFactory.decodeStream(conn.getInputStream())
                if (bmp != null) {
                    currentArtworkBitmap = bmp
                    mainHandler.post {
                        updateArtworkViews()
                        updateMediaSession()
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }.start()
    }

    private fun showOrUpdateIsland() {
        if (islandRootView == null) {
            buildIslandView()
        } else {
            updateIslandViews()
        }
    }

    // ── Build Small Capsule & Root Container ──────────────────────
    private fun buildIslandView() {
        val density = resources.displayMetrics.density

        // Small capsule exact dimensions: ~110dp wide, 28dp high (Image-0)
        val compactWidthPx = (110 * density).toInt()
        val compactHeightPx = (28 * density).toInt()

        val params = WindowManager.LayoutParams(
            compactWidthPx,
            compactHeightPx,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
            y = (7 * density).toInt() // Direct punch-hole alignment
        }
        windowParams = params

        val root = FrameLayout(this)
        islandRootView = root

        renderCompactContent()
        windowManager?.addView(root, params)
        updateMediaSession()
    }

    // ── 1. RENDER COMPACT CAPSULE (Image-0) ─────────────────────────
    private fun renderCompactContent() {
        val root = islandRootView ?: return
        root.removeAllViews()
        isExpanded = false

        val density = resources.displayMetrics.density
        val heightPx = (28 * density).toInt()

        val container = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding((5 * density).toInt(), 0, (5 * density).toInt(), 0)

            // Pure black pill capsule
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = heightPx / 2f
                setColor(Color.parseColor("#000000"))
                setStroke((1f * density).toInt(), Color.parseColor("#222834"))
            }

            // Clicking small capsule expands it!
            setOnClickListener {
                expandIsland()
            }
        }

        // Left Wing: Miniature Album Art thumbnail (18dp × 18dp, rounded 4dp)
        val artThumb = ImageView(this).apply {
            val sz = (18 * density).toInt()
            layoutParams = LinearLayout.LayoutParams(sz, sz).apply {
                marginStart = (2 * density).toInt()
            }
            scaleType = ImageView.ScaleType.CENTER_CROP
            val bmp = currentArtworkBitmap
            if (bmp != null) {
                setImageBitmap(getRoundedCornerBitmap(bmp, 4 * density))
            } else {
                setImageDrawable(createDefaultLogoDrawable(density))
            }
        }
        compactArtView = artThumb
        container.addView(artThumb)

        // Center: Camera punch-hole gap (26dp)
        val centerSpacer = View(this).apply {
            layoutParams = LinearLayout.LayoutParams((26 * density).toInt(), 1)
        }
        container.addView(centerSpacer)

        // Right Wing: Animated 4-bar equalizer visualizer (20dp × 12dp)
        val waveform = WaveformBarsView(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                (20 * density).toInt(),
                (12 * density).toInt()
            ).apply {
                marginEnd = (2 * density).toInt()
            }
            setPlaying(isPlaying)
        }
        compactWaveform = waveform
        container.addView(waveform)

        root.addView(container)
    }

    // ── 2. EXPAND ISLAND (Image-1) ──────────────────────────────────
    private fun expandIsland() {
        val root = islandRootView ?: return
        val wm = windowManager ?: return
        val params = windowParams ?: return

        isExpanded = true
        mainHandler.removeCallbacks(collapseRunnable)
        // Automatically collapse back to small in 5s
        mainHandler.postDelayed(collapseRunnable, 5000)

        val density = resources.displayMetrics.density
        val screenWidth = resources.displayMetrics.widthPixels
        val expandedWidth = (screenWidth - (32 * density)).toInt().coerceAtMost((360 * density).toInt())
        val expandedHeight = (142 * density).toInt()

        params.width = expandedWidth
        params.height = expandedHeight
        params.y = (10 * density).toInt()
        wm.updateViewLayout(root, params)

        root.removeAllViews()

        // Card Container
        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding((16 * density).toInt(), (14 * density).toInt(), (16 * density).toInt(), (12 * density).toInt())

            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = 24 * density
                setColor(Color.parseColor("#0B0E17")) // Deep Black
                setStroke((1.2f * density).toInt(), Color.parseColor("#263244"))
            }

            // Clicking outside media controls opens the AxoR app!
            setOnClickListener {
                val openIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                }
                if (openIntent != null) {
                    startActivity(openIntent)
                    collapseIsland()
                }
            }
        }

        // ── TOP ROW: Album Art + Title & Artist ───────────────────
        val topRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        }

        // Album Art (44dp × 44dp, rounded 10dp)
        val artView = ImageView(this).apply {
            val sz = (44 * density).toInt()
            layoutParams = LinearLayout.LayoutParams(sz, sz).apply {
                marginEnd = (12 * density).toInt()
            }
            scaleType = ImageView.ScaleType.CENTER_CROP
            val bmp = currentArtworkBitmap
            if (bmp != null) {
                setImageBitmap(getRoundedCornerBitmap(bmp, 10 * density))
            } else {
                setImageDrawable(createDefaultLogoDrawable(density))
            }
        }
        expandedArtView = artView
        topRow.addView(artView)

        // Text Column (Title & Artist)
        val textCol = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1.0f)
        }

        val titleTv = TextView(this).apply {
            text = currentTitle
            setTextColor(Color.WHITE)
            textSize = 14f
            typeface = Typeface.DEFAULT_BOLD
            isSingleLine = true
            ellipsize = android.text.TextUtils.TruncateAt.END
        }
        expandedTitleView = titleTv
        textCol.addView(titleTv)

        val artistTv = TextView(this).apply {
            text = currentArtist
            setTextColor(Color.parseColor("#8E9AA8"))
            textSize = 11.5f
            isSingleLine = true
            ellipsize = android.text.TextUtils.TruncateAt.END
            setPadding(0, (2 * density).toInt(), 0, 0)
        }
        expandedArtistView = artistTv
        textCol.addView(artistTv)
        topRow.addView(textCol)

        card.addView(topRow)

        // Spacer
        card.addView(View(this).apply {
            layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, (10 * density).toInt())
        })

        // ── MIDDLE ROW: Position, Progress Bar, Duration ─────────
        val progressRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        }

        val posTv = TextView(this).apply {
            text = formatDuration(currentPositionMs)
            setTextColor(Color.parseColor("#8E9AA8"))
            textSize = 10f
        }
        expandedPosView = posTv
        progressRow.addView(posTv)

        // Progress line
        val pBar = ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal).apply {
            layoutParams = LinearLayout.LayoutParams(0, (4 * density).toInt(), 1.0f).apply {
                marginStart = (10 * density).toInt()
                marginEnd = (10 * density).toInt()
            }
            max = 1000
            progress = if (currentDurationMs > 0) ((currentPositionMs * 1000) / currentDurationMs).toInt() else 0
            progressDrawable = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = 2 * density
                setColor(Color.parseColor("#00F5FF")) // Cyan Neon
            }
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = 2 * density
                setColor(Color.parseColor("#263244"))
            }
        }
        expandedProgressBar = pBar
        progressRow.addView(pBar)

        val durTv = TextView(this).apply {
            text = formatDuration(currentDurationMs)
            setTextColor(Color.parseColor("#8E9AA8"))
            textSize = 10f
        }
        expandedDurView = durTv
        progressRow.addView(durTv)

        card.addView(progressRow)

        // Spacer
        card.addView(View(this).apply {
            layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, (10 * density).toInt())
        })

        // ── BOTTOM ROW: Media Controls (Previous, Play/Pause, Next) 
        val controlsRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        }

        // Previous Button
        val prevBtn = createControlButton(drawPreviousIcon(density)) {
            resetCollapseTimer()
            MainActivity.sendControlAction("previous")
        }
        controlsRow.addView(prevBtn)

        // Spacer
        controlsRow.addView(View(this).apply {
            layoutParams = LinearLayout.LayoutParams((36 * density).toInt(), 1)
        })

        // Play / Pause Button
        val playPauseBtn = createControlButton(
            if (isPlaying) drawPauseIcon(density) else drawPlayIcon(density)
        ) {
            resetCollapseTimer()
            isPlaying = !isPlaying
            MainActivity.sendControlAction("playPause")
            expandedPlayPauseBtn?.setImageBitmap(if (isPlaying) drawPauseIcon(density) else drawPlayIcon(density))
        }
        expandedPlayPauseBtn = playPauseBtn
        controlsRow.addView(playPauseBtn)

        // Spacer
        controlsRow.addView(View(this).apply {
            layoutParams = LinearLayout.LayoutParams((36 * density).toInt(), 1)
        })

        // Next Button
        val nextBtn = createControlButton(drawNextIcon(density)) {
            resetCollapseTimer()
            MainActivity.sendControlAction("next")
        }
        controlsRow.addView(nextBtn)

        card.addView(controlsRow)
        root.addView(card)
    }

    private fun resetCollapseTimer() {
        mainHandler.removeCallbacks(collapseRunnable)
        mainHandler.postDelayed(collapseRunnable, 5000)
    }

    // ── 3. COLLAPSE TO SMALL CAPSULE ──────────────────────────────
    private fun collapseIsland() {
        val root = islandRootView ?: return
        val wm = windowManager ?: return
        val params = windowParams ?: return

        isExpanded = false
        mainHandler.removeCallbacks(collapseRunnable)

        val density = resources.displayMetrics.density
        params.width = (110 * density).toInt()
        params.height = (28 * density).toInt()
        params.y = (7 * density).toInt()
        wm.updateViewLayout(root, params)

        renderCompactContent()
    }

    // ── Updates when song / progress changes ──────────────────────
    private fun updateIslandViews() {
        if (!isExpanded) {
            compactWaveform?.setPlaying(isPlaying)
        } else {
            expandedTitleView?.text = currentTitle
            expandedArtistView?.text = currentArtist
            expandedPosView?.text = formatDuration(currentPositionMs)
            expandedDurView?.text = formatDuration(currentDurationMs)
            val density = resources.displayMetrics.density
            expandedPlayPauseBtn?.setImageBitmap(if (isPlaying) drawPauseIcon(density) else drawPlayIcon(density))
            if (currentDurationMs > 0) {
                expandedProgressBar?.progress = ((currentPositionMs * 1000) / currentDurationMs).toInt()
            }
        }
        updateMediaSession()
    }

    private fun updateArtworkViews() {
        val density = resources.displayMetrics.density
        val bmp = currentArtworkBitmap
        if (bmp != null) {
            compactArtView?.setImageBitmap(getRoundedCornerBitmap(bmp, 4 * density))
            expandedArtView?.setImageBitmap(getRoundedCornerBitmap(bmp, 10 * density))
        }
    }

    private fun hideIsland() {
        mainHandler.removeCallbacks(collapseRunnable)
        if (islandRootView != null) {
            try {
                compactWaveform?.stop()
                windowManager?.removeView(islandRootView)
            } catch (e: Exception) {
                e.printStackTrace()
            } finally {
                islandRootView = null
                compactWaveform = null
                compactArtView = null
                expandedArtView = null
                expandedTitleView = null
                expandedArtistView = null
                isExpanded = false
            }
        }
        try {
            mediaSession?.isActive = false
            mediaSession?.release()
            mediaSession = null
        } catch (_: Exception) {}
    }

    override fun onDestroy() {
        hideIsland()
        super.onDestroy()
    }

    // ── Control Button Helper ────────────────────────────────────
    private fun createControlButton(icon: Bitmap, onClick: () -> Unit): ImageView {
        val density = resources.displayMetrics.density
        val btnSize = (32 * density).toInt()
        return ImageView(this).apply {
            layoutParams = LinearLayout.LayoutParams(btnSize, btnSize)
            scaleType = ImageView.ScaleType.CENTER_INSIDE
            setImageBitmap(icon)
            setOnClickListener { onClick() }
        }
    }

    // ── Draw Vectors programmatically for sharp high-DPI rendering ──
    private fun drawPlayIcon(density: Float): Bitmap {
        val size = (28 * density).toInt()
        val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            style = Paint.Style.FILL
        }
        val path = Path().apply {
            moveTo(size * 0.32f, size * 0.22f)
            lineTo(size * 0.78f, size * 0.50f)
            lineTo(size * 0.32f, size * 0.78f)
            close()
        }
        canvas.drawPath(path, paint)
        return bmp
    }

    private fun drawPauseIcon(density: Float): Bitmap {
        val size = (28 * density).toInt()
        val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#00F5FF") // Cyan pause bars
            style = Paint.Style.FILL
        }
        val barW = size * 0.18f
        val barH = size * 0.56f
        val top = size * 0.22f
        val r = 2f * density
        canvas.drawRoundRect(RectF(size * 0.24f, top, size * 0.24f + barW, top + barH), r, r, paint)
        canvas.drawRoundRect(RectF(size * 0.58f, top, size * 0.58f + barW, top + barH), r, r, paint)
        return bmp
    }

    private fun drawPreviousIcon(density: Float): Bitmap {
        val size = (24 * density).toInt()
        val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#CBD5E1")
            style = Paint.Style.FILL
        }
        // Left bar
        canvas.drawRoundRect(RectF(size * 0.20f, size * 0.25f, size * 0.28f, size * 0.75f), 1.5f * density, 1.5f * density, paint)
        // Left triangle
        val path = Path().apply {
            moveTo(size * 0.75f, size * 0.25f)
            lineTo(size * 0.32f, size * 0.50f)
            lineTo(size * 0.75f, size * 0.75f)
            close()
        }
        canvas.drawPath(path, paint)
        return bmp
    }

    private fun drawNextIcon(density: Float): Bitmap {
        val size = (24 * density).toInt()
        val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#CBD5E1")
            style = Paint.Style.FILL
        }
        // Right bar
        canvas.drawRoundRect(RectF(size * 0.72f, size * 0.25f, size * 0.80f, size * 0.75f), 1.5f * density, 1.5f * density, paint)
        // Right triangle
        val path = Path().apply {
            moveTo(size * 0.25f, size * 0.25f)
            lineTo(size * 0.68f, size * 0.50f)
            lineTo(size * 0.25f, size * 0.75f)
            close()
        }
        canvas.drawPath(path, paint)
        return bmp
    }

    private fun createDefaultLogoDrawable(density: Float): GradientDrawable {
        return GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(Color.parseColor("#00F5FF"))
            setSize((18 * density).toInt(), (18 * density).toInt())
        }
    }

    private fun getRoundedCornerBitmap(bitmap: Bitmap, cornerRadius: Float): Bitmap {
        val output = Bitmap.createBitmap(bitmap.width, bitmap.height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(output)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        val rect = Rect(0, 0, bitmap.width, bitmap.height)
        val rectF = RectF(rect)
        canvas.drawRoundRect(rectF, cornerRadius, cornerRadius, paint)
        paint.xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC_IN)
        canvas.drawBitmap(bitmap, rect, rect, paint)
        return output
    }

    private fun formatDuration(ms: Long): String {
        val totalSec = ms / 1000
        val m = totalSec / 60
        val s = totalSec % 60
        return String.format("%02d:%02d", m, s)
    }

    // ── Custom Equalizer Visualizer View ─────────────────────────
    private class WaveformBarsView(context: Context) : View(context) {
        private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#00F5FF") // Neon Cyan
            style = Paint.Style.FILL
        }

        private val barHeights = floatArrayOf(0.4f, 0.8f, 0.5f, 0.9f)
        private var animator: ValueAnimator? = null
        private var isPlaying = false

        init {
            animator = ValueAnimator.ofFloat(0f, 1f).apply {
                duration = 180
                repeatCount = ValueAnimator.INFINITE
                repeatMode = ValueAnimator.REVERSE
                interpolator = LinearInterpolator()
                addUpdateListener {
                    if (isPlaying) {
                        for (i in barHeights.indices) {
                            val phase = (System.currentTimeMillis() / (120 + i * 40.0))
                            barHeights[i] = (0.25f + 0.70f * Math.abs(Math.sin(phase))).toFloat()
                        }
                        invalidate()
                    }
                }
            }
        }

        fun setPlaying(playing: Boolean) {
            this.isPlaying = playing
            if (playing) {
                if (animator?.isStarted != true) {
                    animator?.start()
                }
            } else {
                for (i in barHeights.indices) {
                    barHeights[i] = 0.2f
                }
                invalidate()
            }
        }

        fun stop() {
            isPlaying = false
            animator?.cancel()
        }

        override fun onDraw(canvas: Canvas) {
            super.onDraw(canvas)
            val w = width.toFloat()
            val h = height.toFloat()
            val numBars = 4
            val barWidth = 2.5f * resources.displayMetrics.density
            val spacing = (w - (numBars * barWidth)) / (numBars + 1)
            val cornerRadius = barWidth / 2f

            for (i in 0 until numBars) {
                val left = spacing + i * (barWidth + spacing)
                val right = left + barWidth
                val barH = h * barHeights[i]
                val top = (h - barH) / 2f
                val bottom = top + barH

                val rect = RectF(left, top, right, bottom)
                canvas.drawRoundRect(rect, cornerRadius, cornerRadius, paint)
            }
        }
    }
}
