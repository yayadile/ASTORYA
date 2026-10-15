package tech.graaf.franz.ar_flutter_plugin_plus

import android.app.Activity
import android.app.Application
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.media.MediaPlayer
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.HandlerThread
import android.os.SystemClock
import android.opengl.GLES20
import android.opengl.GLSurfaceView
import android.opengl.Matrix
import android.util.Log
import android.view.MotionEvent
import android.view.Surface
import android.view.TextureView
import kotlin.math.sqrt
import android.view.PixelCopy
import android.view.View
import android.widget.Toast
import android.widget.FrameLayout
import com.google.ar.core.*
import com.google.ar.core.exceptions.*
import javax.microedition.khronos.egl.EGLConfig
import javax.microedition.khronos.opengles.GL10
import tech.graaf.franz.ar_flutter_plugin_plus.Serialization.deserializeMatrix4
import tech.graaf.franz.ar_flutter_plugin_plus.Serialization.serializeAnchor
import tech.graaf.franz.ar_flutter_plugin_plus.Serialization.serializeHitResult
import tech.graaf.franz.ar_flutter_plugin_plus.Serialization.serializePose
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.loader.FlutterLoader
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import java.io.ByteArrayOutputStream
import java.io.ByteArrayInputStream
import java.io.IOException
import java.io.File
import java.nio.FloatBuffer
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.CompletableFuture
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.regex.Pattern

import android.R
import android.view.ViewGroup
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner














internal class AndroidARView(
        val activity: Activity,
        context: Context,
        messenger: BinaryMessenger,
        id: Int,
        creationParams: Map<String?, Any?>?
) : PlatformView {
    companion object {
        private val cachedImageDatabaseBytes: MutableMap<String, ByteArray> = mutableMapOf()
    }
    private val TAG = "AndroidARView"

    private lateinit var viewContext: Context
    private lateinit var rootView: FrameLayout
    private lateinit var glSurfaceView: GLSurfaceView
    private lateinit var renderer: ArCoreRenderer
    private lateinit var modelRenderer: ModelRenderer
    private var filamentTextureView: TextureView? = null

    private val sessionManagerChannel = MethodChannel(messenger, "arsession_$id")
    private val objectManagerChannel = MethodChannel(messenger, "arobjects_$id")
    private val anchorManagerChannel = MethodChannel(messenger, "aranchors_$id")

    private var session: Session? = null
    private var currentFrame: Frame? = null

    private val backgroundRenderer = BackgroundRenderer()
    private val axisRenderer = AxisRenderer()
    private val planeRenderer = SimplePlaneRenderer()
    private val pointCloudRenderer = PointCloudRenderer()

    private var showFeaturePoints = false
    private var showPlanes = false
    private var showWorldOrigin = false
    private var showAnimatedGuide = false
    private var animatedGuide: View? = null

    private var isARInitialized = false
    private var mUserRequestedInstall = true

    private val tapLock = Any()
    private var queuedTap: MotionEvent? = null

    private var activeGestureNodeName: String? = null
    private var isPanning = false
    private var isRotating = false
    private var lastRotationAngle = 0f

    private var lastTrackingState: TrackingState? = null
    private var lastTrackingFailureReason: TrackingFailureReason? = null

    private var worldOriginAnchor: Anchor? = null
    private var lastWorldOriginMatrix: FloatArray? = null
    private var stableTrackingFrames = 0
    private var nonTrackingFrames = 0
    private val requiredStableTrackingFrames = 10
    private val activeAugmentedImages: MutableSet<String> = mutableSetOf()
    private val lastAugmentedImageUpdateMs: MutableMap<String, Long> = mutableMapOf()
    private var continuousImageTracking = false
    private var imageTrackingUpdateIntervalMs: Long = 100

    // --- Marker corner projection (video-on-marker) -------------------------
    // Marker yang sedang FULL_TRACKING terakhir, dipakai untuk menghitung
    // 4 sudut layar (normalized [0,1]) tiap frame saat render loop berjalan.
    private var activeTrackedImage: AugmentedImage? = null
    private var cornersViewportWidth: Int = 0
    private var cornersViewportHeight: Int = 0

    /// Penanda: payload sudut marker sudah pernah terkirim (untuk mengirim
    /// satu kali event "marker hilang" saat tracking berhenti).
    private var lastCornersSent = false

    /// Alasan terakhir [computeMarkerScreenCorners] mengembalikan null.
    /// Hanya untuk log diagnostik saat marker hilang dari pandangan.
    private var lastCornerNullReason: String = ""

    // --- Video-on-marker (MediaPlayer -> GL quad menempel marker) ------------
    // Dipakai mode native "video model": meshplane.glb memang sebuah plane,
    // jadi videonya digambar sebagai textured quad yang diposisikan per-frame
    // dari sudut layar ARCore (tracking beneran), bukan overlay widget.
    private val markerVideoRenderer = VideoPlaneRenderer()
    private var markerVideoPlayer: MediaPlayer? = null
    private var markerVideoSurface: Surface? = null
    private var markerVideoPrepared = false
    private var markerVideoWantedPlaying = false
    // Pernah start() sukses. Gerbang penting: pause()/stop() SEBELUM pernah
    // start adalah state ilegal bagi MediaPlayer dan melempar error (-38)
    // yang mematikan player (inilah "gagal diputar (what=-38)").
    private var markerVideoStarted = false
    private var markerVideoRotation = 0
    // Mode "pop-up": quad digambar TEGAK menghadap kamera (billboard) dengan
    // kaki di tengah marker, bukan rebah di bidang kertas.
    private var markerVideoUpright = false
    // Mode fullscreen: quad digambar menutupi layar (contain-fit), kamera
    // tidak digambar (efek bioskop). Player tetap sama -> audio VO/BGM
    // tidak terganggu (tanpa player kedua = tanpa rebutan audio focus).
    private var markerVideoFullscreen = false
    private var pendingMarkerVideo: PendingMarkerVideo? = null

    private val nonTrackingResetThreshold = 30
    private val modelIoExecutor = Executors.newFixedThreadPool(2)
    private val imageTrackingExecutor = Executors.newSingleThreadExecutor()
    private var androidModelScaleFactor: Float = 0.33f
    // Setting defaults
    private var enableRotation = false
    private var enablePans = false

    // Logical scene state (ARCore-only, no rendering)
    private val nodesByName: MutableMap<String, SimpleNode> = mutableMapOf()
    private val anchorsByName: MutableMap<String, Anchor> = mutableMapOf()
    private val anchorChildren: MutableMap<String, MutableList<String>> = mutableMapOf()
    private val anchorTransformsByName: MutableMap<String, FloatArray> = mutableMapOf()
    // Cloud anchor handler
    private lateinit var cloudAnchorHandler: CloudAnchorHandler

    private var onFrameUpdateListener: ((Long) -> Unit)? = null
    private var isSessionResumed = false
    private var pendingSessionResume = false
    private lateinit var activityLifecycleCallbacks: Application.ActivityLifecycleCallbacks

    // Method channel handlers
    private val onSessionMethodCall =
            object : MethodChannel.MethodCallHandler {
                override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
                    when (call.method) {
                        "init" -> {
                            initializeARView(call, result)
                        }
                        "setLightIntensityMultiplier" -> {
                            val multiplier = call.argument<Number>("multiplier")?.toFloat() ?: 1.0f
                            modelRenderer.setLightIntensityMultiplier(multiplier)
                            result.success(null)
                        }
                        "updateImageTrackingSettings" -> {
                            val argTrackingImagePaths: List<String>? = call.argument<List<String>>("trackingImagePaths")
                            val argContinuousImageTracking: Boolean? = call.argument<Boolean>("continuousImageTracking")
                            val argImageTrackingUpdateIntervalMs: Number? = call.argument<Number>("imageTrackingUpdateIntervalMs")

                            applyImageTrackingSettings(
                                imagePaths = argTrackingImagePaths,
                                continuous = argContinuousImageTracking,
                                intervalMs = argImageTrackingUpdateIntervalMs
                            )
                            result.success(null)
                        }
                        "precompileImageTrackingDatabase" -> {
                            val argTrackingImagePaths: List<String>? = call.argument<List<String>>("trackingImagePaths")
                            val imagePaths = argTrackingImagePaths ?: emptyList()
                            val session = session
                            if (session == null) {
                                result.error("Error", "Session not initialized", null)
                                return
                            }

                            imageTrackingExecutor.execute {
                                var success = true
                                try {
                                    val cacheKey = imageCacheKey(imagePaths)
                                    if (!cachedImageDatabaseBytes.containsKey(cacheKey)) {
                                        val (imageDatabase, buildSuccess) = buildImageDatabase(session, imagePaths)
                                        success = buildSuccess
                                        val bytes = serializeImageDatabase(imageDatabase)
                                        cachedImageDatabaseBytes[cacheKey] = bytes
                                    }
                                } catch (e: Exception) {
                                    success = false
                                    Log.e(TAG, "Error precompiling image database: ${e.message}")
                                }

                                activity.runOnUiThread {
                                    result.success(success)
                                }
                            }
                        }
                        "getAnchorPose" -> {
                            val anchorName = call.argument<String>("anchorId")
                            val anchor = if (anchorName != null) anchorsByName[anchorName] else null
                            if (anchor != null) {
                                result.success(serializePose(anchor.pose))
                            } else {
                                result.error("Error", "could not get anchor pose", null)
                            }
                        }
                        "getCameraPose" -> {
                            val cameraPose = currentFrame?.camera?.displayOrientedPose
                            if (cameraPose != null) {
                                result.success(serializePose(cameraPose))
                            } else {
                                result.error("Error", "could not get camera pose", null)
                            }
                        }
                        "snapshot" -> {
                            val width = glSurfaceView.width
                            val height = glSurfaceView.height
                            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)

                            // Create a handler thread to offload the processing of the image.
                            val handlerThread = HandlerThread("PixelCopier")
                            handlerThread.start()
                            // Copy the GLSurfaceView (camera + ARCore draws).
                            PixelCopy.request(glSurfaceView, bitmap, { copyResult: Int ->
                                if (copyResult == PixelCopy.SUCCESS) {
                                    try {
                                        val mainHandler = Handler(context.mainLooper)
                                        val runnable = Runnable {
                                            // Composite Filament TextureView on top if available.
                                            filamentTextureView?.let { overlay ->
                                                if (overlay.isAvailable) {
                                                    val overlayBitmap = overlay.getBitmap(width, height)
                                                    if (overlayBitmap != null) {
                                                        val canvas = Canvas(bitmap)
                                                        canvas.drawBitmap(overlayBitmap, 0f, 0f, null)
                                                        overlayBitmap.recycle()
                                                    }
                                                }
                                            }

                                            val stream = ByteArrayOutputStream()
                                            bitmap.compress(Bitmap.CompressFormat.PNG, 90, stream)
                                            val data = stream.toByteArray()
                                            result.success(data)
                                        }
                                        mainHandler.post(runnable)
                                    } catch (e: IOException) {
                                        result.error("e", e.message, e.stackTrace)
                                    }
                                } else {
                                    result.error("e", "failed to take screenshot", null)
                                }
                                handlerThread.quitSafely()
                            }, Handler(handlerThread.looper))
                        }
                        "dispose" -> {
                            dispose()
                        }
                        else -> {}
                    }
                }
            }
    private val onObjectMethodCall =
            object : MethodChannel.MethodCallHandler {
                override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
                    when (call.method) {
                        "init" -> {
                            // objectManagerChannel.invokeMethod("onError", listOf("ObjectTEST from
                            // Android"))
                            val scaleFactor = call.argument<Double>("androidScaleFactor")
                            if (scaleFactor != null) {
                                androidModelScaleFactor = scaleFactor.toFloat()
                            }
                        }
                        "addNode" -> {
                            val dict_node: HashMap<String, Any>? = call.arguments as? HashMap<String, Any>
                            dict_node?.let{
                                addNode(it).thenAccept{status: Boolean ->
                                    result.success(status)
                                }.exceptionally { throwable ->
                                    result.error("e", throwable.message, throwable.stackTrace)
                                    null
                                }
                            }
                        }
                        "addNodeToPlaneAnchor" -> {
                            val dict_node: HashMap<String, Any>? = call.argument<HashMap<String, Any>>("node")
                            val dict_anchor: HashMap<String, Any>? = call.argument<HashMap<String, Any>>("anchor")
                            if (dict_node != null && dict_anchor != null) {
                                addNode(dict_node, dict_anchor).thenAccept{status: Boolean ->
                                    result.success(status)
                                }.exceptionally { throwable ->
                                    result.error("e", throwable.message, throwable.stackTrace)
                                    null
                                }
                            } else {
                                result.success(false)
                            }

                        }
                        "removeNode" -> {
                            val nodeName: String? = call.argument<String>("name")
                            nodeName?.let{
                                nodesByName.remove(nodeName)
                                anchorChildren.values.forEach { it.remove(nodeName) }
                                modelRenderer.removeModel(nodeName)
                                result.success(null)
                            }
                        }
                        "setupMarkerVideo" -> {
                            val videoPath = call.argument<String>("videoPath")
                            if (videoPath.isNullOrEmpty()) {
                                result.error("ARG", "videoPath kosong", null)
                            } else {
                                val kind = call.argument<String>("kind") ?: "asset"
                                val loop = call.argument<Boolean>("loop") ?: true
                                val muted = call.argument<Boolean>("muted") ?: true
                                val autoplay =
                                    call.argument<Boolean>("autoplay") ?: false
                                val rotation =
                                    (call.argument<Number>("rotation")?.toInt())
                                        ?: 0
                                markerVideoRotation = rotation
                                markerVideoUpright =
                                    call.argument<Boolean>("upright") ?: false
                                setupMarkerVideo(
                                    videoPath, kind, loop, muted, autoplay)
                                result.success(true)
                            }
                        }
                        "setMarkerVideoPlaying" -> {
                            val playing =
                                call.argument<Boolean>("playing") ?: false
                            setMarkerVideoPlaying(playing)
                            result.success(null)
                        }
                        "setMarkerVideoFullscreen" -> {
                            markerVideoFullscreen =
                                call.argument<Boolean>("fullscreen") ?: false
                            result.success(null)
                        }
                        "isMarkerVideoReady" -> {
                            // Diagnostik untuk Dart: apakah player siap,
                            // sedang main, atau nyangkut di pending/surface.
                            result.success(mapOf(
                                "prepared" to markerVideoPrepared,
                                "started" to markerVideoStarted,
                                "hasPlayer" to (markerVideoPlayer != null),
                                "hasPending" to (pendingMarkerVideo != null),
                                "rendererReady" to markerVideoRenderer.isReady(),
                                "wantedPlaying" to markerVideoWantedPlaying,
                                "upright" to markerVideoUpright,
                                "fullscreen" to markerVideoFullscreen,
                                "drawCalls" to dbgDrawCalls,
                                "drewFrames" to dbgDrewFrames,
                                "drawSkipped" to dbgDrawSkipped,
                                "lastCorners" to (lastDbgCorners?.toList()
                                    ?: emptyList<Double>())
                            ))
                        }
                        "seekMarkerVideo" -> {
                            val ms =
                                (call.argument<Number>("positionMs")?.toLong())
                                    ?: 0L
                            seekMarkerVideo(ms)
                            result.success(null)
                        }
                        "transformationChanged" -> {
                            val nodeName: String? = call.argument<String>("name")
                            val newTransformation: ArrayList<Double>? = call.argument<ArrayList<Double>>("transformation")
                            nodeName?.let{ name ->
                                newTransformation?.let{ transform ->
                                    transformNode(name, transform)
                                    result.success(null)
                                }
                            }
                        }
                        else -> {}
                    }
                }
            }
    private val onAnchorMethodCall =
            object : MethodChannel.MethodCallHandler {
                override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
                    when (call.method) {
                        "addAnchor" -> {
                            val anchorType: Int? = call.argument<Int>("type")
                            if (anchorType != null){
                                when(anchorType) {
                                    0 -> { // Plane Anchor
                                        val transform: ArrayList<Double>? = call.argument<ArrayList<Double>>("transformation")
                                        val name: String? = call.argument<String>("name")
                                        if ( name != null && transform != null){
                                            result.success(addPlaneAnchor(transform, name))
                                        } else {
                                            result.success(false)
                                        }

                                    }
                                    else -> result.success(false)
                                }
                            } else {
                                result.success(false)
                            }
                        }
                        "removeAnchor" -> {
                            val anchorName: String? = call.argument<String>("name")
                            anchorName?.let{ name ->
                                removeAnchor(name)
                            }
                        }
                        "initGoogleCloudAnchorMode" -> {
                            if (session != null) {
                                val config = Config(session)
                                config.cloudAnchorMode = Config.CloudAnchorMode.ENABLED
                                config.updateMode = Config.UpdateMode.LATEST_CAMERA_IMAGE
                                config.focusMode = Config.FocusMode.AUTO
                                session?.configure(config)

                                cloudAnchorHandler = CloudAnchorHandler(session!!)
                            } else {
                                sessionManagerChannel.invokeMethod("onError", listOf("Error initializing cloud anchor mode: Session is null"))
                            }
                        }
                        "uploadAnchor" ->  {
                            val anchorName: String? = call.argument<String>("name")
                            val ttl: Int? = call.argument<Int>("ttl")
                            anchorName?.let {
                                val anchor = anchorsByName[anchorName]
                                if (ttl != null) {
                                    cloudAnchorHandler.hostCloudAnchorWithTtl(anchorName, anchor, cloudAnchorUploadedListener(), ttl!!)
                                } else {
                                    cloudAnchorHandler.hostCloudAnchor(anchorName, anchor, cloudAnchorUploadedListener())
                                }
                                result.success(true)
                            }

                        }
                        "downloadAnchor" -> {
                            val anchorId: String? = call.argument<String>("cloudanchorid")
                            anchorId?.let {
                                cloudAnchorHandler.resolveCloudAnchor(anchorId, cloudAnchorDownloadedListener())
                            }
                        }
                        else -> {}
                    }
                }
            }

    override fun getView(): View {
        return rootView
    }

    override fun dispose() {
        // Destroy AR session
        try {
            onPause()
            onDestroy()
            // ARCore session cleanup handled in onDestroy
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    init {
        viewContext = context

        rootView = FrameLayout(context)
        rootView.layoutParams = FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        )

        glSurfaceView = GLSurfaceView(context)
        glSurfaceView.layoutParams = FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        )
        glSurfaceView.setEGLContextClientVersion(3)
        glSurfaceView.setEGLConfigChooser(8, 8, 8, 8, 16, 0)
        glSurfaceView.preserveEGLContextOnPause = true
        renderer = ArCoreRenderer()
        glSurfaceView.setRenderer(renderer)
        glSurfaceView.renderMode = GLSurfaceView.RENDERMODE_CONTINUOUSLY

        modelRenderer = ModelRenderer()

        rootView.addView(glSurfaceView)

        // Filament overlay removed for step-by-step testing

        glSurfaceView.addOnLayoutChangeListener { _, _, _, _, _, _, _, _, _ ->
            val width = glSurfaceView.width
            val height = glSurfaceView.height
            if (width > 0 && height > 0) {
                glSurfaceView.queueEvent {
                    renderer.onLayoutChanged(width, height)
                }
            }
        }

        glSurfaceView.setOnTouchListener { _, motionEvent ->
            val handled = handleGestureTouch(motionEvent)
            if (!handled) {
                onTap(null, motionEvent)
            }
            true
        }

        setupLifeCycle(context)

        sessionManagerChannel.setMethodCallHandler(onSessionMethodCall)
        objectManagerChannel.setMethodCallHandler(onObjectMethodCall)
        anchorManagerChannel.setMethodCallHandler(onAnchorMethodCall)

        // Don't call onResume here - wait for initializeARView to configure the session first
    }

    private fun setupLifeCycle(context: Context) {
        activityLifecycleCallbacks =
                object : Application.ActivityLifecycleCallbacks {
                    override fun onActivityCreated(
                            activity: Activity,
                            savedInstanceState: Bundle?
                    ) {
                    }

                    override fun onActivityStarted(activity: Activity) {
                    }

                    override fun onActivityResumed(activity: Activity) {
                        if (isARInitialized) {
                            this@AndroidARView.onResume()
                        }
                    }

                    override fun onActivityPaused(activity: Activity) {
                        try {
                            session?.pause()
                        } catch (e: Exception) {
                            Log.e(TAG, "Error in onActivityPaused: ${e.message}")
                        }
                        
                        this@AndroidARView.onPause()
                    }

                    override fun onActivityStopped(activity: Activity) {
                        // onStopped()
                        this@AndroidARView.onPause()
                    }

                    override fun onActivitySaveInstanceState(
                            activity: Activity,
                            outState: Bundle
                    ) {}

                    override fun onActivityDestroyed(activity: Activity) {
//                        onPause()
//                        onDestroy()
                    }
                }

        activity.application.registerActivityLifecycleCallbacks(this.activityLifecycleCallbacks)
    }

    fun onResume() {
        glSurfaceView.onResume()
        // Lanjutkan video marker bila sebelum pause sedang diinginkan main.
        if (markerVideoWantedPlaying && markerVideoPrepared) {
            try {
                markerVideoPlayer?.start()
            } catch (_: Exception) {
            }
        }
        if (!renderer.isSurfaceCreated) {
            pendingSessionResume = true
            return
        }
        resumeSessionInternal()
    }

    fun onPause() {
        // hide instructions view if no longer required
        if (showAnimatedGuide){
            animatedGuide?.let { guide ->
                val view = activity.findViewById(R.id.content) as ViewGroup
                view.removeView(guide)
            }
            showAnimatedGuide = false
        }
        glSurfaceView.onPause()
        // Jeda video marker (flag wanted tetap, dilanjutkan di onResume).
        // Hanya bila pernah start: pause() sebelumnya = state ilegal (-38).
        if (markerVideoStarted) {
            try {
                markerVideoPlayer?.pause()
            } catch (_: Exception) {
            }
        }
        activeAugmentedImages.clear()
        lastAugmentedImageUpdateMs.clear()
        activeTrackedImage = null
        lastCornersSent = false
        isSessionResumed = false
    }

    private fun resumeSessionInternal() {
        try {
            session?.resume()
            isSessionResumed = true
            pendingSessionResume = false
        } catch (e: Exception) {
            Log.e(TAG, "Error resuming session: ${e.message}")
        }
    }

    fun onDestroy() {
        try {
            worldOriginAnchor?.detach()
            worldOriginAnchor = null
            modelRenderer.destroy()
            releaseMarkerVideoPlayer()
            try {
                glSurfaceView.queueEvent { markerVideoRenderer.release() }
            } catch (_: Exception) {
            }
            session?.close()
            session = null

            activeAugmentedImages.clear()
            lastAugmentedImageUpdateMs.clear()
            activeTrackedImage = null
            lastCornersSent = false

            modelIoExecutor.shutdown()
            imageTrackingExecutor.shutdown()
            
            onFrameUpdateListener = null
        } catch (e: Exception) {
            Log.e(TAG, "Error in onDestroy: ${e.message}")
            e.printStackTrace()
        }
    }

    private fun initializeARView(call: MethodCall, result: MethodChannel.Result) {
        // Unpack call arguments
        val argShowFeaturePoints: Boolean? = call.argument<Boolean>("showFeaturePoints")
        val argPlaneDetectionConfig: Int? = call.argument<Int>("planeDetectionConfig")
        val argShowPlanes: Boolean? = call.argument<Boolean>("showPlanes")
        val argCustomPlaneTexturePath: String? = call.argument<String>("customPlaneTexturePath")
        val argShowWorldOrigin: Boolean? = call.argument<Boolean>("showWorldOrigin")
        val argHandleTaps: Boolean? = call.argument<Boolean>("handleTaps")
        val argHandleRotation: Boolean? = call.argument<Boolean>("handleRotation")
        val argHandlePans: Boolean? = call.argument<Boolean>("handlePans")
        val argShowAnimatedGuide: Boolean? = call.argument<Boolean>("showAnimatedGuide")
        val argTrackingImagePaths: List<String>? = call.argument<List<String>>("trackingImagePaths")
        val argContinuousImageTracking: Boolean? = call.argument<Boolean>("continuousImageTracking")
        val argImageTrackingUpdateIntervalMs: Number? = call.argument<Number>("imageTrackingUpdateIntervalMs")
        val argLightIntensityMultiplier: Number? = call.argument<Number>("lightIntensityMultiplier")

        // Set up frame update listener
        onFrameUpdateListener = { frameTimeNanos ->
            onFrame(frameTimeNanos)
        }

        // Ensure ARCore is installed
        try {
            val installStatus = ArCoreApk.getInstance().requestInstall(activity, !mUserRequestedInstall)
            if (installStatus == ArCoreApk.InstallStatus.INSTALL_REQUESTED) {
                mUserRequestedInstall = false
                result.success(null)
                return
            }
        } catch (e: UnavailableArcoreNotInstalledException) {
            result.error("ARCore", "ARCore not installed", e)
            return
        } catch (e: UnavailableApkTooOldException) {
            result.error("ARCore", "ARCore APK too old", e)
            return
        } catch (e: UnavailableSdkTooOldException) {
            result.error("ARCore", "ARCore SDK too old", e)
            return
        } catch (e: UnavailableDeviceNotCompatibleException) {
            result.error("ARCore", "ARCore not compatible with this device", e)
            return
        }


        // Configure Plane scanning guide (UI handled by Flutter if needed)
        if (argShowAnimatedGuide == true) {
            showAnimatedGuide = true
        }

        // Create and configure ARCore session
        if (session == null) {
            session = Session(activity)
            renderer.session = session
            if (backgroundRenderer.textureId != -1) {
                session?.setCameraTextureName(backgroundRenderer.textureId)
            }
            renderer.onSessionReady()
        }

        val config = session!!.config
        when (argPlaneDetectionConfig) {
            1 -> config.planeFindingMode = Config.PlaneFindingMode.HORIZONTAL
            2 -> config.planeFindingMode = Config.PlaneFindingMode.VERTICAL
            3 -> config.planeFindingMode = Config.PlaneFindingMode.HORIZONTAL_AND_VERTICAL
            else -> config.planeFindingMode = Config.PlaneFindingMode.DISABLED
        }
        config.depthMode = Config.DepthMode.DISABLED
        config.updateMode = Config.UpdateMode.BLOCKING
        config.focusMode = Config.FocusMode.AUTO
        session!!.configure(config)

        // Configure image tracking
        applyImageTrackingSettings(
            imagePaths = argTrackingImagePaths,
            continuous = argContinuousImageTracking,
            intervalMs = argImageTrackingUpdateIntervalMs
        )

        // Feature points/planes/world origin rendering is handled by the GL renderer
        showFeaturePoints = argShowFeaturePoints == true
        showPlanes = argShowPlanes == true
        showWorldOrigin = argShowWorldOrigin == true
        if (!showWorldOrigin) {
            worldOriginAnchor?.detach()
            worldOriginAnchor = null
        }

        // Configure gestures
        enableRotation = argHandleRotation == true
        enablePans = argHandlePans == true

        // Now that configuration is complete, start the AR session
        if (!isARInitialized) {
            onResume()
            isARInitialized = true
        }

        // Apply lighting multiplier if provided
        argLightIntensityMultiplier?.toFloat()?.let { multiplier ->
            modelRenderer.setLightIntensityMultiplier(multiplier)
        }

        result.success(null)
    }

    private fun onFrame(frameTimeNanos: Long) {
        val frame = currentFrame ?: return
        
        // hide instructions view if no longer required
        if (showAnimatedGuide){
            for (plane in frame.getUpdatedTrackables(Plane::class.java)) {
                if (plane.trackingState === TrackingState.TRACKING) {
                    animatedGuide?.let { guide ->
                        val view = activity.findViewById(R.id.content) as ViewGroup
                        view.removeView(guide)
                    }
                    showAnimatedGuide = false
                    break
                }
            }
        }

        // Feature points are rendered in the GL renderer when enabled.
        
        val updatedAnchors = frame.updatedAnchors
        // Notify the cloudManager of all the updates.
        if (this::cloudAnchorHandler.isInitialized) { cloudAnchorHandler.onUpdate(updatedAnchors) }

        // Check for image tracking
        checkForTrackedImages()


    }

    private fun addNode(dict_node: HashMap<String, Any>, dict_anchor: HashMap<String, Any>? = null): CompletableFuture<Boolean>{
        val completableFutureSuccess: CompletableFuture<Boolean> = CompletableFuture()

        try {
            val nodeName = dict_node["name"] as String
            val transformation = dict_node["transformation"] as ArrayList<Double>
            val nodeType = dict_node["type"] as Int
            val uri = dict_node["uri"] as String

            val anchorName: String? = dict_anchor?.get("name") as? String
            nodesByName[nodeName] = SimpleNode(nodeName, transformation, nodeType, uri, anchorName)

            if (anchorName != null) {
                val children = anchorChildren.getOrPut(anchorName) { mutableListOf() }
                if (!children.contains(nodeName)) {
                    children.add(nodeName)
                }
            }

            loadModelForNode(nodeName)
            completableFutureSuccess.complete(true)
        } catch (e: java.lang.Exception) {
            completableFutureSuccess.completeExceptionally(e)
        }

        return completableFutureSuccess
    }

    private fun loadModelForNode(nodeName: String) {
        val node = nodesByName[nodeName] ?: return

        activity.runOnUiThread {
            ensureFilamentOverlay()
        }

        modelIoExecutor.execute {
            try {
                when (node.type) {
                    0 -> { // localGLTF2
                        val gltfBytes = readFlutterAssetBytes(node.uri)
                        val basePath = node.uri.substringBeforeLast("/", "")
                        val resourceMap = loadGltfResourcesFromAssets(gltfBytes, basePath)
                        // Parsing glTF with external resources is not yet wired; keep step-by-step.
                        glSurfaceView.queueEvent {
                            modelRenderer.loadGltf(node.name, gltfBytes, resourceMap)
                        }
                    }
                    1 -> { // localGLB
                        val glbBytes = readFlutterAssetBytes(node.uri)
                        glSurfaceView.queueEvent {
                            modelRenderer.loadGlb(node.name, glbBytes)
                        }
                    }
                    2 -> { // webGLB
                        val glbBytes = readUrlBytes(node.uri)
                        glSurfaceView.queueEvent {
                            modelRenderer.loadGlb(node.name, glbBytes)
                        }
                    }
                    3 -> { // fileSystemAppFolderGLB
                        val glbBytes = readFileBytes(node.uri)
                        glSurfaceView.queueEvent {
                            modelRenderer.loadGlb(node.name, glbBytes)
                        }
                    }
                    4 -> { // fileSystemAppFolderGLTF2
                        val gltfBytes = readFileBytes(node.uri)
                        val basePath = File(node.uri).parent ?: ""
                        val resourceMap = loadGltfResourcesFromFile(gltfBytes, basePath)
                        // Parsing glTF with external resources is not yet wired; keep step-by-step.
                        glSurfaceView.queueEvent {
                            modelRenderer.loadGltf(node.name, gltfBytes, resourceMap)
                        }
                    }
                    else -> {
                        activity.runOnUiThread {
                            sessionManagerChannel.invokeMethod("onError", listOf("Unsupported node type ${node.type}"))
                        }
                    }
                }
            } catch (e: Exception) {
                activity.runOnUiThread {
                    sessionManagerChannel.invokeMethod("onError", listOf("Error loading model: ${e.message}"))
                }
            }
        }
    }

    private fun readFlutterAssetBytes(path: String): ByteArray {
        val loader = FlutterInjector.instance().flutterLoader()
        if (!loader.initialized()) {
            loader.startInitialization(viewContext)
            loader.ensureInitializationComplete(viewContext, null)
        }
        val key = loader.getLookupKeyForAsset(path)
        return viewContext.assets.open(key).readBytes()
    }

    private fun readUrlBytes(url: String): ByteArray {
        val connection = URL(url).openConnection() as HttpURLConnection
        connection.connectTimeout = 15000
        connection.readTimeout = 15000
        connection.requestMethod = "GET"
        connection.connect()
        connection.inputStream.use { input ->
            return input.readBytes()
        }
    }

    private fun readFileBytes(path: String): ByteArray {
        val file = if (path.startsWith("file://")) File(Uri.parse(path).path ?: path) else File(path)
        return file.readBytes()
    }

    private fun loadGltfResourcesFromAssets(gltfBytes: ByteArray, basePath: String): Map<String, ByteArray> {
        val json = String(gltfBytes)
        val uris = extractGltfUris(json)
        val resources = mutableMapOf<String, ByteArray>()
        for (uri in uris) {
            val data = decodeDataUri(uri) ?: run {
                val assetPath = if (basePath.isNotEmpty()) "$basePath/$uri" else uri
                readFlutterAssetBytes(assetPath)
            }
            resources[uri] = data
        }
        return resources
    }

    private fun loadGltfResourcesFromFile(gltfBytes: ByteArray, basePath: String): Map<String, ByteArray> {
        val json = String(gltfBytes)
        val uris = extractGltfUris(json)
        val resources = mutableMapOf<String, ByteArray>()
        for (uri in uris) {
            val data = decodeDataUri(uri) ?: run {
                val filePath = if (basePath.isNotEmpty()) "$basePath/$uri" else uri
                readFileBytes(filePath)
            }
            resources[uri] = data
        }
        return resources
    }

    private fun extractGltfUris(json: String): List<String> {
        val pattern = Pattern.compile("\\\"uri\\\"\\s*:\\s*\\\"([^\\\"]+)\\\"")
        val matcher = pattern.matcher(json)
        val uris = mutableListOf<String>()
        while (matcher.find()) {
            val uri = matcher.group(1)
            if (!uri.isNullOrBlank()) {
                uris.add(uri)
            }
        }
        return uris.distinct()
    }

    private fun decodeDataUri(uri: String): ByteArray? {
        if (!uri.startsWith("data:")) return null
        val parts = uri.split(",", limit = 2)
        if (parts.size != 2) return null
        return try {
            android.util.Base64.decode(parts[1], android.util.Base64.DEFAULT)
        } catch (e: Exception) {
            null
        }
    }

    private fun updateModelTransforms() {
        val nodeMatrix = FloatArray(16)
        val anchorMatrix = FloatArray(16)
        val modelMatrix = FloatArray(16)
        val scaleMatrix = FloatArray(16)
        val scaledModelMatrix = FloatArray(16)

        nodesByName.values.forEach { node ->
            matrixFromTransform(node.transformation, nodeMatrix)
            val anchorName = node.anchorName
            if (anchorName != null) {
                val anchor = anchorsByName[anchorName]
                if (anchor != null && anchor.trackingState != TrackingState.STOPPED) {
                    anchor.pose.toMatrix(anchorMatrix, 0)
                    Matrix.multiplyMM(modelMatrix, 0, anchorMatrix, 0, nodeMatrix, 0)
                } else {
                    val fallbackAnchor = anchorTransformsByName[anchorName]
                    if (fallbackAnchor != null) {
                        System.arraycopy(fallbackAnchor, 0, anchorMatrix, 0, 16)
                        Matrix.multiplyMM(modelMatrix, 0, anchorMatrix, 0, nodeMatrix, 0)
                    } else {
                        System.arraycopy(nodeMatrix, 0, modelMatrix, 0, 16)
                    }
                }
            } else {
                System.arraycopy(nodeMatrix, 0, modelMatrix, 0, 16)
            }
            val modelScaleFactor = getModelScaleFactor(node.type)
            if (modelScaleFactor != 1.0f) {
                Matrix.setIdentityM(scaleMatrix, 0)
                Matrix.scaleM(scaleMatrix, 0, modelScaleFactor, modelScaleFactor, modelScaleFactor)
                Matrix.multiplyMM(scaledModelMatrix, 0, modelMatrix, 0, scaleMatrix, 0)
                modelRenderer.updateTransform(node.name, scaledModelMatrix)
            } else {
                modelRenderer.updateTransform(node.name, modelMatrix)
            }
        }
    }

    private fun getModelScaleFactor(nodeType: Int): Float {
        return when (nodeType) {
            0, 1, 2, 3, 4 -> androidModelScaleFactor
            else -> 1.0f
        }
    }

    private fun matrixFromTransform(transform: ArrayList<Double>, outMatrix: FloatArray) {
        if (transform.size < 16) {
            Matrix.setIdentityM(outMatrix, 0)
            return
        }
        for (i in 0 until 16) {
            outMatrix[i] = transform[i].toFloat()
        }
    }

    private fun transformNode(name: String, transform: ArrayList<Double>) {
        val node = nodesByName[name]
        if (node != null) {
            node.transformation = transform
        }
    }

    private fun onTap(hitNode: Any?, motionEvent: MotionEvent?): Boolean {
        if (motionEvent != null && motionEvent.action == MotionEvent.ACTION_DOWN) {
            synchronized(tapLock) {
                queuedTap?.recycle()
                queuedTap = MotionEvent.obtain(motionEvent)
            }
            return true
        }
        return false
    }

    private fun handleGestureTouch(motionEvent: MotionEvent?): Boolean {
        if (motionEvent == null) return false
        if (!enablePans && !enableRotation) return false

        val frame = currentFrame ?: return false
        when (motionEvent.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                val hitPose = hitTestPlaneOrPoint(frame, motionEvent)
                val nearest = hitPose?.let { findNearestNode(it) } ?: findNearestNodeToCamera(frame)
                if (nearest == null) return false

                activeGestureNodeName = nearest.name
                isPanning = enablePans
                isRotating = false
                lastRotationAngle = 0f

                if (isPanning) {
                    objectManagerChannel.invokeMethod("onPanStart", nearest.name)
                }
                return true
            }
            MotionEvent.ACTION_POINTER_DOWN -> {
                if (!enableRotation || motionEvent.pointerCount < 2) return isPanning
                if (activeGestureNodeName == null) {
                    val midEvent = motionEventMidpoint(motionEvent) ?: return false
                    val hitPose = hitTestPlaneOrPoint(frame, midEvent)
                    midEvent.recycle()
                    val nearest = hitPose?.let { findNearestNode(it) } ?: findNearestNodeToCamera(frame)
                    if (nearest == null) return false
                    activeGestureNodeName = nearest.name
                }
                isRotating = true
                isPanning = false
                lastRotationAngle = rotationAngle(motionEvent)
                activeGestureNodeName?.let { name ->
                    objectManagerChannel.invokeMethod("onRotationStart", name)
                }
                return true
            }
            MotionEvent.ACTION_MOVE -> {
                val nodeName = activeGestureNodeName ?: return false
                val node = nodesByName[nodeName] ?: return false

                if (isRotating && enableRotation && motionEvent.pointerCount >= 2) {
                    val currentAngle = rotationAngle(motionEvent)
                    val delta = currentAngle - lastRotationAngle
                    lastRotationAngle = currentAngle

                    rotateNode(node, delta)
                    objectManagerChannel.invokeMethod("onRotationChange", node.name)
                    return true
                }

                if (isPanning && enablePans) {
                    val hitPose = hitTestPlaneOrPoint(frame, motionEvent) ?: return false
                    moveNodeToPose(node, hitPose)
                    objectManagerChannel.invokeMethod("onPanChange", node.name)
                    return true
                }
                return false
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                val nodeName = activeGestureNodeName
                if (nodeName != null) {
                    val node = nodesByName[nodeName]
                    val transform = node?.transformation
                    if (isPanning && transform != null) {
                        objectManagerChannel.invokeMethod(
                            "onPanEnd",
                            mapOf("name" to nodeName, "transform" to transform)
                        )
                    }
                    if (isRotating && transform != null) {
                        objectManagerChannel.invokeMethod(
                            "onRotationEnd",
                            mapOf("name" to nodeName, "transform" to transform)
                        )
                    }
                }
                activeGestureNodeName = null
                isPanning = false
                isRotating = false
                lastRotationAngle = 0f
                return false
            }
            else -> return false
        }
    }

    private fun hitTestPlaneOrPoint(frame: Frame, motionEvent: MotionEvent): Pose? {
        val hitResults = frame.hitTest(motionEvent)
        val hit = hitResults.firstOrNull { result ->
            when (val trackable = result.trackable) {
                is Plane -> trackable.trackingState == TrackingState.TRACKING &&
                        trackable.isPoseInPolygon(result.hitPose)
                is Point -> trackable.trackingState == TrackingState.TRACKING
                else -> false
            }
        }
        return hit?.hitPose
    }

    private fun findNearestNode(hitPose: Pose): SimpleNode? {
        if (nodesByName.isEmpty()) return null
        var nearest: SimpleNode? = null
        var minDist = Float.MAX_VALUE
        val hitX = hitPose.tx()
        val hitY = hitPose.ty()
        val hitZ = hitPose.tz()

        nodesByName.values.forEach { node ->
            val pos = getNodeWorldPosition(node)
            val dx = pos[0] - hitX
            val dy = pos[1] - hitY
            val dz = pos[2] - hitZ
            val dist = dx * dx + dy * dy + dz * dz
            if (dist < minDist) {
                minDist = dist
                nearest = node
            }
        }
        return nearest
    }

    private fun findNearestNodeToCamera(frame: Frame): SimpleNode? {
        if (nodesByName.isEmpty()) return null
        val cameraPose = frame.camera.pose
        val camX = cameraPose.tx()
        val camY = cameraPose.ty()
        val camZ = cameraPose.tz()

        var nearest: SimpleNode? = null
        var minDist = Float.MAX_VALUE
        nodesByName.values.forEach { node ->
            val pos = getNodeWorldPosition(node)
            val dx = pos[0] - camX
            val dy = pos[1] - camY
            val dz = pos[2] - camZ
            val dist = dx * dx + dy * dy + dz * dz
            if (dist < minDist) {
                minDist = dist
                nearest = node
            }
        }
        return nearest
    }

    private fun getNodeWorldPosition(node: SimpleNode): FloatArray {
        val nodeMatrix = FloatArray(16)
        val anchorMatrix = FloatArray(16)
        val modelMatrix = FloatArray(16)
        matrixFromTransform(node.transformation, nodeMatrix)
        val anchorName = node.anchorName
        if (anchorName != null) {
            val anchor = anchorsByName[anchorName]
            if (anchor != null && anchor.trackingState != TrackingState.STOPPED) {
                anchor.pose.toMatrix(anchorMatrix, 0)
                Matrix.multiplyMM(modelMatrix, 0, anchorMatrix, 0, nodeMatrix, 0)
            } else {
                val fallbackAnchor = anchorTransformsByName[anchorName]
                if (fallbackAnchor != null) {
                    System.arraycopy(fallbackAnchor, 0, anchorMatrix, 0, 16)
                    Matrix.multiplyMM(modelMatrix, 0, anchorMatrix, 0, nodeMatrix, 0)
                } else {
                    System.arraycopy(nodeMatrix, 0, modelMatrix, 0, 16)
                }
            }
        } else {
            System.arraycopy(nodeMatrix, 0, modelMatrix, 0, 16)
        }
        return floatArrayOf(modelMatrix[12], modelMatrix[13], modelMatrix[14])
    }

    private fun moveNodeToPose(node: SimpleNode, hitPose: Pose) {
        val targetPose = if (node.anchorName != null) {
            val anchor = anchorsByName[node.anchorName]
            if (anchor != null && anchor.trackingState != TrackingState.STOPPED) {
                anchor.pose.inverse().compose(hitPose)
            } else {
                hitPose
            }
        } else {
            hitPose
        }

        val transform = node.transformation
        if (transform.size < 16) return
        transform[12] = targetPose.tx().toDouble()
        transform[13] = targetPose.ty().toDouble()
        transform[14] = targetPose.tz().toDouble()
        node.transformation = transform
    }

    private fun rotateNode(node: SimpleNode, deltaRadians: Float) {
        val transform = node.transformation
        if (transform.size < 16) return

        val matrix = FloatArray(16)
        matrixFromTransform(transform, matrix)
        val deltaDegrees = Math.toDegrees(deltaRadians.toDouble()).toFloat()
        Matrix.rotateM(matrix, 0, deltaDegrees, 0f, 1f, 0f)

        val updated = ArrayList<Double>(16)
        for (i in 0 until 16) {
            updated.add(matrix[i].toDouble())
        }
        node.transformation = updated
    }

    private fun rotationAngle(event: MotionEvent): Float {
        if (event.pointerCount < 2) return 0f
        val dx = event.getX(1) - event.getX(0)
        val dy = event.getY(1) - event.getY(0)
        return kotlin.math.atan2(dy, dx)
    }

    private fun motionEventMidpoint(event: MotionEvent): MotionEvent? {
        if (event.pointerCount < 2) return null
        val x = (event.getX(0) + event.getX(1)) / 2f
        val y = (event.getY(0) + event.getY(1)) / 2f
        val downTime = event.downTime
        val eventTime = event.eventTime
        return MotionEvent.obtain(downTime, eventTime, MotionEvent.ACTION_DOWN, x, y, 0)
    }

    private fun addPlaneAnchor(transform: ArrayList<Double>, name: String): Boolean {
        val session = session ?: return false
        val components = try {
            deserializeMatrix4(transform)
        } catch (_: Exception) {
            return false
        }

        val future = CompletableFuture<Boolean>()
        glSurfaceView.queueEvent {
            try {
                val anchor = session.createAnchor(Pose(components.position, components.rotation))
                anchorsByName[name] = anchor
                anchorChildren.putIfAbsent(name, mutableListOf())
                val anchorMatrix = FloatArray(16)
                matrixFromTransform(transform, anchorMatrix)
                anchorTransformsByName[name] = anchorMatrix
                future.complete(true)
            } catch (e: Exception) {
                future.complete(false)
            }
        }

        return try {
            future.get(2, TimeUnit.SECONDS)
        } catch (_: Exception) {
            false
        }
    }

    private fun removeAnchor(name: String) {
        val anchor = anchorsByName.remove(name)
        anchor?.detach()
        anchorChildren.remove(name)
        anchorTransformsByName.remove(name)
    }

    private fun handleQueuedTap(frame: Frame) {
        val tap = synchronized(tapLock) {
            val value = queuedTap
            queuedTap = null
            value
        } ?: return

        try {
            val allHitResults = frame.hitTest(tap)
            val planeAndPointHitResults = allHitResults.filter { hit ->
                when (val trackable = hit.trackable) {
                    is Plane -> trackable.trackingState == TrackingState.TRACKING &&
                            trackable.isPoseInPolygon(hit.hitPose)
                    is Point -> trackable.trackingState == TrackingState.TRACKING
                    else -> false
                }
            }

            val serializedPlaneAndPointHitResults: ArrayList<HashMap<String, Any>> =
                ArrayList(planeAndPointHitResults.map { serializeHitResult(it) })

            activity.runOnUiThread {
                sessionManagerChannel.invokeMethod(
                    "onPlaneOrPointTap",
                    serializedPlaneAndPointHitResults
                )
            }
        } finally {
            tap.recycle()
        }
    }

    private inner class cloudAnchorUploadedListener: CloudAnchorHandler.CloudAnchorListener {
        override fun onCloudTaskComplete(anchorName: String?, anchor: Anchor?) {
            val cloudState = anchor!!.cloudAnchorState
            if (cloudState.isError) {
                Log.e(TAG, "Error uploading anchor, state $cloudState")
                sessionManagerChannel.invokeMethod("onError", listOf("Error uploading anchor, state $cloudState"))
                return
            }
            // Swap old and new anchor for the name
            if (anchorName != null) {
                val oldAnchor = anchorsByName[anchorName]
                anchorsByName[anchorName] = anchor!!
                oldAnchor?.detach()
            }

            val args = HashMap<String, String?>()
            args["name"] = anchorName
            args["cloudanchorid"] = anchor.cloudAnchorId
            anchorManagerChannel.invokeMethod("onCloudAnchorUploaded", args)
        }
    }

    private inner class cloudAnchorDownloadedListener: CloudAnchorHandler.CloudAnchorListener {
        override fun onCloudTaskComplete(anchorName: String?, anchor: Anchor?) {
            val cloudState = anchor!!.cloudAnchorState
            if (cloudState.isError) {
                Log.e(TAG, "Error downloading anchor, state $cloudState")
                sessionManagerChannel.invokeMethod("onError", listOf("Error downloading anchor, state $cloudState"))
                return
            }
            val anchorIdName = anchorName ?: ""
            anchorsByName[anchorIdName] = anchor!!
            anchorChildren.putIfAbsent(anchorIdName, mutableListOf())
            // Register new anchor on the Flutter side of the plugin
            anchorManagerChannel.invokeMethod(
                "onAnchorDownloadSuccess",
                serializeAnchor(anchorIdName, anchor, anchorChildren[anchorIdName] ?: emptyList()),
                object: MethodChannel.Result {
                override fun success(result: Any?) {
                    val registeredName = result.toString()
                    if (registeredName.isNotEmpty() && registeredName != anchorIdName) {
                        val existing = anchorsByName.remove(anchorIdName)
                        if (existing != null) {
                            anchorsByName[registeredName] = existing
                        }
                        val children = anchorChildren.remove(anchorIdName)
                        if (children != null) {
                            anchorChildren[registeredName] = children
                        }
                    }
                }

                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                    sessionManagerChannel.invokeMethod("onError", listOf("Error while registering downloaded anchor at the AR Flutter plugin: $errorMessage"))
                }

                override fun notImplemented() {
                    sessionManagerChannel.invokeMethod("onError", listOf("Error while registering downloaded anchor at the AR Flutter plugin"))
                }
            })
        }
    }

    private fun checkForTrackedImages() {
        val frame = currentFrame ?: return
        
        val updatedAugmentedImages = frame.getUpdatedTrackables(AugmentedImage::class.java)
        
        val now = SystemClock.uptimeMillis()
        for (augmentedImage in updatedAugmentedImages) {
            // Throttle: log per-frame menenggelamkan diagnostik video di
            // logcat (buffer kecil). Cukup 3x pertama + tiap perubahan state.
            if (dbgTrackLogs < 3) {
                dbgTrackLogs++
                Log.i(TAG, "AugmentedImage detected: name=${augmentedImage.name}, state=${augmentedImage.trackingState}, method=${augmentedImage.trackingMethod}")
            }
            when (augmentedImage.trackingState) {
                TrackingState.TRACKING -> {
                    // Hanya FULL_TRACKING yang dipercaya. Terbukti via log:
                    // saat LAST_KNOWN_POSE, centerPose degenerat menempel
                    // kamera (imgT == camT persis) sehingga me-render quad
                    // raksasa melayang + node nyasar. LAST_KNOWN diperlakukan
                    // hilang: bersihkan state agar deteksi berikutnya segar.
                    if (augmentedImage.trackingMethod !=
                        AugmentedImage.TrackingMethod.FULL_TRACKING) {
                        if (activeTrackedImage?.name == augmentedImage.name) {
                            activeTrackedImage = null
                        }
                        augmentedImage.name?.let { name ->
                            activeAugmentedImages.remove(name)
                            lastAugmentedImageUpdateMs.remove(name)
                        }
                        continue
                    }
                    // FULL_TRACKING: pose valid (Y lokal = normal marker,
                    // terverifikasi empiris via log).
                    val imageName = augmentedImage.name ?: "unknown"
                    val centerPose = augmentedImage.centerPose
                    val transformation = serializePose(centerPose)
                    // Dipakai render loop untuk proyeksi 4 sudut layar video.
                    activeTrackedImage = augmentedImage
                    val shouldEmit = if (continuousImageTracking) {
                        val lastUpdate = lastAugmentedImageUpdateMs[imageName] ?: 0L
                        now - lastUpdate >= imageTrackingUpdateIntervalMs
                    } else {
                        !activeAugmentedImages.contains(imageName)
                    }

                    if (shouldEmit) {
                        emitImageDetection(imageName, transformation)
                        if (continuousImageTracking) {
                            lastAugmentedImageUpdateMs[imageName] = now
                        }
                    }

                    activeAugmentedImages.add(imageName)
                }
                TrackingState.PAUSED -> {
                    if (activeTrackedImage?.name == augmentedImage.name) {
                        activeTrackedImage = null
                    }
                }
                TrackingState.STOPPED -> {
                    augmentedImage.name?.let { name ->
                        activeAugmentedImages.remove(name)
                        lastAugmentedImageUpdateMs.remove(name)
                    }
                    if (activeTrackedImage?.name == augmentedImage.name) {
                        activeTrackedImage = null
                    }
                }
            }
        }
    }

    private fun emitImageDetection(imageName: String, transformation: DoubleArray) {
        val arguments = HashMap<String, Any>()
        arguments["imageName"] = imageName
        arguments["transformation"] = transformation

        activity.runOnUiThread {
            sessionManagerChannel.invokeMethod("onImageDetected", arguments)
        }
    }

    /// Proyeksikan 4 sudut fisik marker ke koordinat layar ternormalisasi
    /// [0,1] relatif terhadap permukaan AR (glSurfaceView).
    ///
    /// Marker berada di bidang XY ruang lokalnya (Z keluar bidang). Sudut lokal
    /// di-transform ke ruang dunia memakai centerPose, lalu view -> clip ->
    /// NDC, dan akhirnya dinormalisasi ke [0,1]. Y dibalik karena sumbu Y layar
    /// mengarah ke bawah.
    ///
    /// Mengembalikan DoubleArray 8 elemen [x0,y0, x1,y1, x2,y2, x3,y3] dengan
    /// urutan: top-left, top-right, bottom-right, bottom-left (saat marker
    /// menghadap kamera lurus). Return null bila kamera/viewport belum siap.
    private fun computeMarkerScreenCorners(): DoubleArray? {
        val image = activeTrackedImage
        if (image == null || image.trackingState != TrackingState.TRACKING) {
            lastCornerNullReason = "image=${image?.trackingState ?: "null"}"
            return null
        }
        // Sabuk ganda: hanya FULL_TRACKING (LAST_KNOWN_POSE = pose degenerat).
        if (image.trackingMethod !=
            AugmentedImage.TrackingMethod.FULL_TRACKING) {
            lastCornerNullReason = "method=${image.trackingMethod}"
            return null
        }
        val frame = currentFrame
        if (frame == null) {
            lastCornerNullReason = "frame=null"
            return null
        }
        val camera = frame.camera
        if (camera.trackingState != TrackingState.TRACKING) {
            lastCornerNullReason =
                "camera=${camera.trackingState}/${camera.trackingFailureReason}"
            return null
        }

        var vpW = cornersViewportWidth
        var vpH = cornersViewportHeight
        if (vpW <= 0 || vpH <= 0) {
            // Fallback: pakai ukuran GLSurfaceView bila ukuran surface khusus
            // sudut belum terisi (mencegah video selalu jatuh ke mode datar).
            // (viewportWidth/Height milik inner renderer, tak terlihat dari sini.)
            vpW = glSurfaceView.width
            vpH = glSurfaceView.height
        }
        if (vpW <= 0 || vpH <= 0) {
            lastCornerNullReason = "viewport=${cornersViewportWidth}x${cornersViewportHeight}/view=${glSurfaceView.width}x${glSurfaceView.height}"
            return null
        }
        lastCornerNullReason = ""

        val pose = image.centerPose
        // ARCore AugmentedImage coordinate system (TERVERIFIKASI empiris via
        // log saat FULL_TRACKING: sumbu lokal Y = (0,1,0) dunia = normal
        // keluar marker):
        // +X: horizontal right across the face of the image
        // +Y: normal vector pointing straight OUT of the image plane (towards camera)
        // -Z: top of the image, +Z: bottom of the image
        // extentX: physical width, extentZ: physical height
        val halfW = image.extentX / 2.0f
        val halfH = image.extentZ / 2.0f

        // 4 titik DUNIA quad — dua mode:
        // - rebah (default): 4 sudut fisik marker (Y lokal = 0).
        // - tegak (billboard): quad vertikal menghadap kamera, kaki di
        //   tengah marker. Lebar = lebar fisik marker, tinggi mengikuti
        //   aspek video agar tidak gepeng.
        val worldCorners = FloatArray(12)

        // Rotasi vektor lokal -> dunia memakai quaternion pose (pengganti
        // Pose.transformPoint offset yang rusak di build ini).
        val pt = pose.translation
        val pq = pose.rotationQuaternion
        val qx = pq[0]
        val qy = pq[1]
        val qz = pq[2]
        val qw = pq[3]
        fun rotVec(lx: Float, ly: Float, lz: Float, out: FloatArray) {
            val tx = 2f * (qy * lz - qz * ly)
            val ty = 2f * (qz * lx - qx * lz)
            val tz = 2f * (qx * ly - qy * lx)
            out[0] = lx + qw * tx + (qy * tz - qz * ty)
            out[1] = ly + qw * ty + (qz * tx - qx * tz)
            out[2] = lz + qw * tz + (qx * ty - qy * tx)
        }

        if (!markerVideoUpright) {
            // 0: top-left     (-halfW, 0f, -halfH)
            // 1: top-right    ( halfW, 0f, -halfH)
            // 2: bottom-right ( halfW, 0f,  halfH)
            // 3: bottom-left  (-halfW, 0f,  halfH)
            val tmp = FloatArray(3)
            rotVec(-halfW, 0f, -halfH, tmp)
            worldCorners[0] = pt[0] + tmp[0]
            worldCorners[1] = pt[1] + tmp[1]
            worldCorners[2] = pt[2] + tmp[2]
            rotVec(halfW, 0f, -halfH, tmp)
            worldCorners[3] = pt[0] + tmp[0]
            worldCorners[4] = pt[1] + tmp[1]
            worldCorners[5] = pt[2] + tmp[2]
            rotVec(halfW, 0f, halfH, tmp)
            worldCorners[6] = pt[0] + tmp[0]
            worldCorners[7] = pt[1] + tmp[1]
            worldCorners[8] = pt[2] + tmp[2]
            rotVec(-halfW, 0f, halfH, tmp)
            worldCorners[9] = pt[0] + tmp[0]
            worldCorners[10] = pt[1] + tmp[1]
            worldCorners[11] = pt[2] + tmp[2]
        } else {
            val vw = markerVideoPlayer?.videoWidth ?: 0
            val vh = markerVideoPlayer?.videoHeight ?: 0
            val aspect = if (vw > 0 && vh > 0) vw.toFloat() / vh else 16f / 9f
            val wHalf = image.extentX / 2f
            val hHalf = image.extentX / aspect / 2f
            // Sumbu X marker + normal marker di ruang dunia.
            val xAxis = FloatArray(3)
            val normal = FloatArray(3)
            rotVec(1f, 0f, 0f, xAxis)
            rotVec(0f, 1f, 0f, normal)
            // Tengah quad: tengah marker + normal * (setengah tinggi + 1 cm)
            // sehingga tepi bawahnya menapak di atas kertas.
            val cx = pt[0] + normal[0] * (hHalf + 0.01f)
            val cy = pt[1] + normal[1] * (hHalf + 0.01f)
            val cz = pt[2] + normal[2] * (hHalf + 0.01f)
            // Normal quad menghadap kamera.
            val camPos = camera.pose.translation
            var nx = camPos[0] - cx
            var ny = camPos[1] - cy
            var nz = camPos[2] - cz
            var nl = sqrt(nx * nx + ny * ny + nz * nz)
            if (nl < 1e-6f) {
                nx = normal[0]
                ny = normal[1]
                nz = normal[2]
                nl = sqrt(nx * nx + ny * ny + nz * nz)
                if (nl < 1e-6f) {
                    nx = 0f
                    ny = 0f
                    nz = 1f
                    nl = 1f
                }
            }
            nx /= nl
            ny /= nl
            nz /= nl
            // right = normalize(cross(up0, n)); fallback sumbu X marker
            // bila kamera tepat di atas (degenerat).
            var rx = nz
            var ry = 0f
            var rz = -nx
            var rl = sqrt(rx * rx + rz * rz)
            if (rl < 1e-6f) {
                rx = xAxis[0]
                ry = xAxis[1]
                rz = xAxis[2]
                rl = sqrt(rx * rx + ry * ry + rz * rz)
                if (rl < 1e-6f) {
                    rx = 1f
                    ry = 0f
                    rz = 0f
                    rl = 1f
                }
            }
            rx /= rl
            ry /= rl
            rz /= rl
            // up = cross(n, r) — tegak lurus kamera & right.
            val ux = ny * rz - nz * ry
            val uy = nz * rx - nx * rz
            val uz = nx * ry - ny * rx
            worldCorners[0] = cx - rx * wHalf + ux * hHalf
            worldCorners[1] = cy - ry * wHalf + uy * hHalf
            worldCorners[2] = cz - rz * wHalf + uz * hHalf
            worldCorners[3] = cx + rx * wHalf + ux * hHalf
            worldCorners[4] = cy + ry * wHalf + uy * hHalf
            worldCorners[5] = cz + rz * wHalf + uz * hHalf
            worldCorners[6] = cx + rx * wHalf - ux * hHalf
            worldCorners[7] = cy + ry * wHalf - uy * hHalf
            worldCorners[8] = cz + rz * wHalf - uz * hHalf
            worldCorners[9] = cx - rx * wHalf - ux * hHalf
            worldCorners[10] = cy - ry * wHalf - uy * hHalf
            worldCorners[11] = cz - rz * wHalf - uz * hHalf
        }

        val viewMatrix = FloatArray(16)
        val projectionMatrix = FloatArray(16)
        camera.getViewMatrix(viewMatrix, 0)
        camera.getProjectionMatrix(projectionMatrix, 0, 0.1f, 100.0f)

        val result = DoubleArray(8)
        val worldVec = FloatArray(4)
        val viewVec = FloatArray(4)
        val clipVec = FloatArray(4)

        for (i in 0 until 4) {
            worldVec[0] = worldCorners[i * 3]
            worldVec[1] = worldCorners[i * 3 + 1]
            worldVec[2] = worldCorners[i * 3 + 2]
            worldVec[3] = 1.0f

            android.opengl.Matrix.multiplyMV(viewVec, 0, viewMatrix, 0, worldVec, 0)
            android.opengl.Matrix.multiplyMV(clipVec, 0, projectionMatrix, 0, viewVec, 0)

            val w = clipVec[3]
            if (w <= 0.001f) return null
            val ndcX = clipVec[0] / w
            val ndcY = clipVec[1] / w

            result[i * 2] = ((ndcX + 1.0f) / 2.0f).toDouble()
            result[i * 2 + 1] = ((1.0f - ndcY) / 2.0f).toDouble()
        }
        return result
    }

    /// Kirim 4 sudut layar marker ke Flutter (dipanggil tiap frame render).
    ///
    /// Bila marker hilang (compute null) setelah sebelumnya terkirim, kirim
    /// satu kali payload "hilang" (tanpa `screenCorners`) agar Flutter
    /// menyembunyikan video, lalu berhenti mengirim sampai marker kembali.
    private fun emitMarkerCorners() {
        val corners = computeMarkerScreenCorners()
        if (corners == null) {
            if (lastCornersSent) {
                lastCornersSent = false
                // Diagnostik: catat KENAPA marker dianggap hilang. Ini satu-satunya
                // jalur yang membuat video disembunyikan oleh Flutter.
                Log.w(
                    TAG,
                    "marker LOST: reason=$lastCornerNullReason " +
                        "imgState=${activeTrackedImage?.trackingState} " +
                        "method=${activeTrackedImage?.trackingMethod} " +
                        "cont=$continuousImageTracking " +
                        "activeSet=$activeAugmentedImages"
                )
                activity.runOnUiThread {
                    sessionManagerChannel.invokeMethod(
                        "onMarkerCorners",
                        HashMap<String, Any>()
                    )
                }
            }
            return
        }
        lastCornersSent = true
        val arguments = HashMap<String, Any>()
        arguments["screenCorners"] = corners
        arguments["viewportWidth"] = cornersViewportWidth
        arguments["viewportHeight"] = cornersViewportHeight
        // Kunci payload tetap "extentX"/"extentY" sesuai kontrak di
        // ARMarkerCorners (Dart). Nilai "extentY" = tinggi marker = extentZ ARCore.
        arguments["extentX"] = activeTrackedImage?.extentX?.toDouble() ?: 0.2
        arguments["extentY"] = activeTrackedImage?.extentZ?.toDouble() ?: 0.2
        activity.runOnUiThread {
            sessionManagerChannel.invokeMethod("onMarkerCorners", arguments)
        }
    }

    // ------------------------------------------------------- marker video ---
    // WAJIB dipanggil di UI thread (MediaPlayer butuh Looper untuk callback).
    // Semua pemanggil (method channel, lifecycle) sudah di UI thread kecuali
    // [onMarkerVideoSurfaceReady] yang mem-post ke UI thread lebih dulu.

    private fun setupMarkerVideo(
        videoPath: String,
        kind: String,
        loop: Boolean,
        muted: Boolean,
        autoplay: Boolean,
    ) {
        releaseMarkerVideoPlayer()
        markerVideoWantedPlaying = autoplay
        val surfaceTexture = markerVideoRenderer.surfaceTexture
        if (surfaceTexture == null) {
            // Surface GL belum ada (belum onSurfaceCreated): tunda sampai siap.
            pendingMarkerVideo =
                PendingMarkerVideo(videoPath, kind, loop, muted, autoplay)
            return
        }
        try {
            val player = MediaPlayer()
            when (kind) {
                "url" -> player.setDataSource(videoPath)
                "file" -> {
                    val p = if (videoPath.startsWith("file://")) {
                        android.net.Uri.parse(videoPath).path ?: videoPath
                    } else {
                        videoPath
                    }
                    player.setDataSource(p)
                }
                else -> setAssetDataSource(player, videoPath)
            }
            player.isLooping = loop
            val vol = if (muted) 0f else 1f
            player.setVolume(vol, vol)
            val surface = Surface(surfaceTexture)
            markerVideoSurface?.release()
            markerVideoSurface = surface
            player.setSurface(surface)
            player.setOnPreparedListener { mp ->
                markerVideoPrepared = true
                Log.i(TAG, "MarkerVideo prepared " +
                    "(${mp.videoWidth}x${mp.videoHeight}), " +
                    "wantedPlaying=$markerVideoWantedPlaying")
                try {
                    val w = mp.videoWidth
                    val h = mp.videoHeight
                    if (w > 0 && h > 0) {
                        surfaceTexture.setDefaultBufferSize(w, h)
                    }
                } catch (_: Exception) {
                }
                if (markerVideoWantedPlaying) {
                    try {
                        mp.start()
                        markerVideoStarted = true
                    } catch (_: Exception) {
                    }
                }
            }
            player.setOnErrorListener { _, what, extra ->
                Log.e(TAG, "MarkerVideo error what=$what extra=$extra")
                try {
                    sessionManagerChannel.invokeMethod(
                        "onError",
                        listOf("Video marker gagal diputar " +
                            "(what=$what extra=$extra)."))
                } catch (_: Exception) {
                    // View sudah dispose - banner tak dibutuhkan.
                }
                releaseMarkerVideoPlayer()
                true
            }
            markerVideoPlayer = player
            Log.i(TAG, "setupMarkerVideo: preparing kind=$kind " +
                "autoplay=$autoplay path=$videoPath")
            player.prepareAsync()
        } catch (e: Exception) {
            Log.e(TAG, "setupMarkerVideo: ${e.message}")
            sessionManagerChannel.invokeMethod(
                "onError",
                listOf("Video marker gagal dimuat: ${e.message}"))
            releaseMarkerVideoPlayer()
        }
    }

    private fun setAssetDataSource(player: MediaPlayer, assetPath: String) {
        val loader = FlutterInjector.instance().flutterLoader()
        val key = loader.getLookupKeyForAsset(assetPath)
        try {
            viewContext.assets.openFd(key).use { fd ->
                player.setDataSource(
                    fd.fileDescriptor, fd.startOffset, fd.length)
            }
        } catch (e: Exception) {
            // Aset terkompresi tidak mendukung openFd: salin ke cache dulu.
            Log.w(TAG, "openFd gagal ($key), fallback salin ke cache")
            val ext = assetPath.substringAfterLast('.', "")
            val out = File(viewContext.cacheDir,
                "marker_video" + if (ext.isNotEmpty()) ".$ext" else ".mp4")
            viewContext.assets.open(key).use { input ->
                out.outputStream().use { output -> input.copyTo(output) }
            }
            player.setDataSource(out.absolutePath)
        }
    }

    private fun setMarkerVideoPlaying(playing: Boolean) {
        markerVideoWantedPlaying = playing
        val player = markerVideoPlayer
        if (player == null || !markerVideoPrepared) return
        try {
            if (playing) {
                player.start()
                markerVideoStarted = true
            } else if (markerVideoStarted) {
                // pause() sebelum pernah start() = state ilegal (-38).
                player.pause()
            }
        } catch (e: Exception) {
            Log.e(TAG, "setMarkerVideoPlaying: ${e.message}")
        }
    }

    private fun seekMarkerVideo(positionMs: Long) {
        val player = markerVideoPlayer
        if (player == null || !markerVideoPrepared) return
        try {
            player.seekTo(positionMs.toInt())
        } catch (e: Exception) {
            Log.e(TAG, "seekMarkerVideo: ${e.message}")
        }
    }

    /// Dipanggil dari `onSurfaceCreated` (GL thread) setelah renderer siap.
    private fun onMarkerVideoSurfaceReady() {
        val pending = pendingMarkerVideo ?: return
        pendingMarkerVideo = null
        activity.runOnUiThread {
            setupMarkerVideo(pending.videoPath, pending.kind,
                pending.loop, pending.muted, pending.autoplay)
        }
    }

    /// Gambar quad video di atas marker. Dipanggil tiap frame render
    /// (GL thread) dari `onDrawFrame`. Batal bila belum prepared / marker
    /// tidak terlihat (video disembunyikan, benar secara AR).
    private var dbgCornerLogs = 0
    private var dbgNotPreparedLogs = 0
    private var dbgTrackLogs = 0
    private var dbgDrawCalls = 0L
    private var dbgDrewFrames = 0L
    private var dbgDrawSkipped = 0L
    private var lastDbgCorners: DoubleArray? = null

    private fun drawMarkerVideo() {
        dbgDrawCalls++
        if (!markerVideoPrepared || markerVideoPlayer == null) {
            if (dbgNotPreparedLogs < 3) {
                dbgNotPreparedLogs++
                Log.i(TAG, "DBG_VIDEO not prepared " +
                    "(prepared=$markerVideoPrepared, " +
                    "player=${markerVideoPlayer != null}, " +
                    "pending=${pendingMarkerVideo != null})")
            }
            return
        }
        // Fullscreen: abaikan sudut marker (tetap tampil walau marker
        // hilang), gambar contain-fit menutupi layar.
        if (markerVideoFullscreen) {
            val vw = if (cornersViewportWidth > 0) {
                cornersViewportWidth
            } else {
                glSurfaceView.width
            }
            val vh = if (cornersViewportHeight > 0) {
                cornersViewportHeight
            } else {
                glSurfaceView.height
            }
            val p = markerVideoPlayer
            val aspect =
                if (p != null && p.videoWidth > 0 && p.videoHeight > 0) {
                    p.videoWidth.toFloat() / p.videoHeight
                } else {
                    16f / 9f
                }
            if (markerVideoRenderer.drawFullscreen(
                    vw, vh, aspect, markerVideoRotation)) {
                dbgDrewFrames++
            } else {
                dbgDrawSkipped++
            }
            return
        }
        val corners = computeMarkerScreenCorners()
        if (corners == null) {
            if (dbgCornerLogs < 3) {
                dbgCornerLogs++
                Log.i(TAG, "DBG_CORNERS null reason=$lastCornerNullReason")
            }
            return
        }
        lastDbgCorners = corners
        if (dbgCornerLogs < 3) {
            dbgCornerLogs++
            Log.i(TAG, "DBG_CORNERS " +
                corners.joinToString(",") { "%.3f".format(it) })
        }
        if (markerVideoRenderer.draw(corners, markerVideoRotation)) {
            dbgDrewFrames++
        } else {
            dbgDrawSkipped++
        }
    }

    private fun releaseMarkerVideoPlayer() {
        markerVideoPrepared = false
        markerVideoStarted = false
        // Sengaja TANPA stop(): stop() di state yang salah (idle/preparing/
        // error) juga memicu error (-38). release() legal di semua state dan
        // sudah menghentikan output audio/video.
        try {
            markerVideoPlayer?.release()
        } catch (_: Exception) {
        }
        markerVideoPlayer = null
        try {
            markerVideoSurface?.release()
        } catch (_: Exception) {
        }
        markerVideoSurface = null
    }

    private fun applyImageTrackingSettings(
        imagePaths: List<String>?,
        continuous: Boolean?,
        intervalMs: Number?
    ) {
        if (continuous != null) {
            continuousImageTracking = continuous
        }
        if (intervalMs != null) {
            imageTrackingUpdateIntervalMs = intervalMs.toLong()
        }
        imagePaths?.let { setupImageTrackingAsync(it) }
    }

    private fun imageCacheKey(imagePaths: List<String>): String {
        return imagePaths.joinToString("|")
    }

    private fun buildImageDatabase(session: Session, imagePaths: List<String>): Pair<AugmentedImageDatabase, Boolean> {
        val imageDatabase = AugmentedImageDatabase(session)
        var success = true

        for (imagePath in imagePaths) {
            try {
                val loader = FlutterInjector.instance().flutterLoader()
                val key = loader.getLookupKeyForAsset(imagePath)
                Log.i(TAG, "Attempting to load asset with key: $key for path: $imagePath")

                val inputStream = viewContext.assets.open(key)
                val bitmap = android.graphics.BitmapFactory.decodeStream(inputStream)
                inputStream.close()

                if (bitmap != null) {
                    val imageName = imagePath.substringAfterLast("/").substringBeforeLast(".")
                    val aspect = bitmap.width.toFloat() / bitmap.height.toFloat()
                    // If image is A4 landscape (842x595 ~ 1.414), standard physical width is 0.297m (29.7cm).
                    // If image is A4 portrait (595x842 ~ 0.707), standard physical width is 0.210m (21.0cm).
                    // Default fallback: 0.24m.
                    val physicalWidth = when {
                        aspect in 1.30f..1.55f -> 0.297f
                        aspect in 0.65f..0.75f -> 0.210f
                        else -> 0.24f
                    }
                    Log.i(TAG, "Decoded bitmap for $imageName: ${bitmap.width}x${bitmap.height}, adding with physicalWidth=$physicalWidth")
                    val index = imageDatabase.addImage(imageName, bitmap, physicalWidth)
                    Log.i(TAG, "Added image $imageName to AugmentedImageDatabase, index=$index")

                    if (index == -1) {
                        Log.e(TAG, "Failed to add image to database: $imageName")
                        success = false
                    }
                } else {
                    Log.e(TAG, "Failed to load bitmap for: $imagePath")
                    success = false
                }
            } catch (e: Exception) {
                success = false
                when (e.javaClass.simpleName) {
                    "ImageInsufficientQualityException" -> {
                        Log.e(TAG, "CRITICAL: Image '$imagePath' has insufficient quality for AR tracking! ${e.message}")
                        activity.runOnUiThread {
                            sessionManagerChannel.invokeMethod(
                                "onError",
                                listOf("Image '$imagePath' has insufficient quality for AR tracking. Use images with more visual features like high contrast, corners, and varied textures.")
                            )
                        }
                    }
                    else -> {
                        Log.e(TAG, "Error loading image $imagePath: ${e.message}")
                    }
                }
                e.printStackTrace()
            }
        }

        return Pair(imageDatabase, success)
    }

    private fun serializeImageDatabase(imageDatabase: AugmentedImageDatabase): ByteArray {
        val outputStream = ByteArrayOutputStream()
        imageDatabase.serialize(outputStream)
        return outputStream.toByteArray()
    }

    private fun setupImageTrackingAsync(imagePaths: List<String>) {
        val session = session ?: return
        Log.i(TAG, "setupImageTrackingAsync called with imagePaths: $imagePaths")
        imageTrackingExecutor.execute {
            try {
                val cacheKey = imageCacheKey(imagePaths)
                val cachedBytes = cachedImageDatabaseBytes[cacheKey]
                if (cachedBytes != null) {
                    activity.runOnUiThread {
                        try {
                            val config = session.config
                            val inputStream = ByteArrayInputStream(cachedBytes)
                            val imageDatabase = AugmentedImageDatabase.deserialize(session, inputStream)
                            config.augmentedImageDatabase = imageDatabase
                            session.configure(config)
                            sessionManagerChannel.invokeMethod(
                                "onImageTrackingConfigured",
                                mapOf("success" to true, "cached" to true)
                            )
                        } catch (e: Exception) {
                            Log.e(TAG, "Error applying cached image database: ${e.message}")
                            sessionManagerChannel.invokeMethod(
                                "onError",
                                listOf("Error applying cached image database: ${e.message}")
                            )
                            sessionManagerChannel.invokeMethod(
                                "onImageTrackingConfigured",
                                mapOf("success" to false)
                            )
                        }
                    }
                    return@execute
                }

                val (imageDatabase, success) = buildImageDatabase(session, imagePaths)
                val bytes = serializeImageDatabase(imageDatabase)
                cachedImageDatabaseBytes[cacheKey] = bytes

                activity.runOnUiThread {
                    try {
                        val config = session.config
                        config.augmentedImageDatabase = imageDatabase
                        session.configure(config)
                        sessionManagerChannel.invokeMethod(
                            "onImageTrackingConfigured",
                            mapOf("success" to success)
                        )
                    } catch (e: Exception) {
                        Log.e(TAG, "Error setting up image tracking: ${e.message}")
                        sessionManagerChannel.invokeMethod(
                            "onError",
                            listOf("Error setting up image tracking: ${e.message}")
                        )
                        sessionManagerChannel.invokeMethod(
                            "onImageTrackingConfigured",
                            mapOf("success" to false)
                        )
                    }
                }
            } catch (e: Exception) {
                activity.runOnUiThread {
                    Log.e(TAG, "Error setting up image tracking: ${e.message}")
                    sessionManagerChannel.invokeMethod(
                        "onError",
                        listOf("Error setting up image tracking: ${e.message}")
                    )
                    sessionManagerChannel.invokeMethod(
                        "onImageTrackingConfigured",
                        mapOf("success" to false)
                    )
                }
            }
        }
    }

    private inner class ArCoreRenderer : GLSurfaceView.Renderer {
        var session: Session? = null
        private var viewportWidth: Int = 0
        private var viewportHeight: Int = 0
        private var lastRotation: Int = -1
        var isSurfaceCreated = false
            private set
        private var hasSurface = false
        private var displayGeometryApplied = false

        fun onSessionReady() {
            displayGeometryApplied = false
            applyDisplayGeometryIfAvailable()
            if (backgroundRenderer.textureId != -1) {
                session?.setCameraTextureName(backgroundRenderer.textureId)
            }
        }

        fun onLayoutChanged(width: Int, height: Int) {
            viewportWidth = width
            viewportHeight = height
            // Sudut marker dinormalisasi [0,1] jadi nilai absolutnya tidak
            // penting, tapi HARUS > 0 agar computeMarkerScreenCorners tidak
            // selalu null. onSurfaceChanged kadang tidak dipanggil ulang
            // (mis. PlatformView di-resize), jadi sinkronkan di sini juga.
            cornersViewportWidth = width
            cornersViewportHeight = height
            displayGeometryApplied = false
            if (hasSurface) {
                GLES20.glViewport(0, 0, width, height)
            }
            applyDisplayGeometryIfAvailable()
        }

        private fun applyDisplayGeometryIfAvailable() {
            if (viewportWidth <= 0 || viewportHeight <= 0) {
                return
            }
            val rotation = activity.windowManager.defaultDisplay.rotation
            if (!displayGeometryApplied || rotation != lastRotation) {
                lastRotation = rotation
                session?.setDisplayGeometry(rotation, viewportWidth, viewportHeight)
                displayGeometryApplied = true
            }
        }

        override fun onSurfaceCreated(gl: GL10?, config: EGLConfig?) {
            GLES20.glClearColor(0f, 0f, 0f, 1f)
            backgroundRenderer.initialize()
            axisRenderer.initialize()
            planeRenderer.initialize()
            pointCloudRenderer.initialize()
            // SurfaceTexture video dibuat di GL thread; bila setup video
            // sudah diminta lebih dulu, langsung lanjutkan di UI thread.
            if (markerVideoRenderer.initialize()) {
                onMarkerVideoSurfaceReady()
            }
            session?.setCameraTextureName(backgroundRenderer.textureId)
            isSurfaceCreated = true
            if (pendingSessionResume) {
                activity.runOnUiThread {
                    resumeSessionInternal()
                }
            }
        }

        override fun onSurfaceChanged(gl: GL10?, width: Int, height: Int) {
            viewportWidth = width
            viewportHeight = height
            cornersViewportWidth = width
            cornersViewportHeight = height
            hasSurface = true
            displayGeometryApplied = false
            GLES20.glViewport(0, 0, width, height)
            if (width > 0 && height > 0) {
                lastRotation = activity.windowManager.defaultDisplay.rotation
                session?.setDisplayGeometry(lastRotation, width, height)
                displayGeometryApplied = true
            }
        }

        override fun onDrawFrame(gl: GL10?) {
            GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT or GLES20.GL_DEPTH_BUFFER_BIT)
            try {
                if (!isSessionResumed) {
                    return
                }
                if (viewportWidth <= 0 || viewportHeight <= 0) {
                    val width = glSurfaceView.width
                    val height = glSurfaceView.height
                    if (width > 0 && height > 0) {
                        onLayoutChanged(width, height)
                    } else {
                        return
                    }
                }
                applyDisplayGeometryIfAvailable()
                val frame = session?.update() ?: return
                currentFrame = frame
                handleQueuedTap(frame)
                onFrameUpdateListener?.invoke(frame.timestamp)
                val camera = frame.camera
                val cameraTrackingState = camera.trackingState
                val trackingFailureReason = if (cameraTrackingState == TrackingState.PAUSED) {
                    camera.trackingFailureReason
                } else {
                    com.google.ar.core.TrackingFailureReason.NONE
                }

                if (lastTrackingState != cameraTrackingState ||
                    lastTrackingFailureReason != trackingFailureReason) {
                    lastTrackingState = cameraTrackingState
                    lastTrackingFailureReason = trackingFailureReason
                    activity.runOnUiThread {
                        sessionManagerChannel.invokeMethod(
                            "onTrackingState",
                            mapOf(
                                "state" to cameraTrackingState.name,
                                "reason" to trackingFailureReason.name
                            )
                        )
                    }
                }
                // Fullscreen video: kamera tidak digambar (layar sudah hitam
                // dari glClear di awal frame) agar efek bioskop penuh.
                // Quad video tetap digambar di bawah oleh drawMarkerVideo.
                // Bila player belum siap, kamera tetap tampil seperti biasa.
                if (!markerVideoFullscreen || !markerVideoPrepared ||
                    markerVideoPlayer == null) {
                    backgroundRenderer.draw(frame)
                }

                val viewMatrix = FloatArray(16)
                val projectionMatrix = FloatArray(16)
                camera.getViewMatrix(viewMatrix, 0)
                camera.getProjectionMatrix(projectionMatrix, 0, 0.1f, 100.0f)

                // Kirim 4 sudut layar marker ke Flutter tiap frame (untuk
                // warp video menempel pada marker). Bila tidak ada marker
                // aktif, fungsi ini batal sendiri tanpa kirim apa pun.
                emitMarkerCorners()

                // Quad video model digambar tepat di atas bidang marker
                // (tracking per-frame; hilang bila marker tak terlihat).
                drawMarkerVideo()

                if (showPlanes) {
                    val planes = session?.getAllTrackables(Plane::class.java) ?: emptyList()
                    planeRenderer.draw(planes, viewMatrix, projectionMatrix)
                }

                if (showFeaturePoints) {
                    val pointCloud = frame.acquirePointCloud()
                    pointCloudRenderer.draw(pointCloud, viewMatrix, projectionMatrix)
                    pointCloud.release()
                }

                if (showWorldOrigin) {
                    val cameraTracking = frame.camera.trackingState == TrackingState.TRACKING
                    if (cameraTracking) {
                        stableTrackingFrames++
                        nonTrackingFrames = 0
                    } else {
                        stableTrackingFrames = 0
                        nonTrackingFrames++
                        if (nonTrackingFrames >= nonTrackingResetThreshold) {
                            worldOriginAnchor?.detach()
                            worldOriginAnchor = null
                            lastWorldOriginMatrix = null
                        }
                    }

                    if (worldOriginAnchor == null && stableTrackingFrames >= requiredStableTrackingFrames) {
                        worldOriginAnchor = session?.createAnchor(Pose.IDENTITY)
                    }

                    worldOriginAnchor?.let { anchor ->
                        if (anchor.trackingState == TrackingState.TRACKING) {
                            val modelMatrix = FloatArray(16)
                            anchor.pose.toMatrix(modelMatrix, 0)
                            lastWorldOriginMatrix = modelMatrix
                            axisRenderer.draw(frame, modelMatrix)
                        } else if (anchor.trackingState != TrackingState.STOPPED) {
                            lastWorldOriginMatrix?.let { frozenMatrix ->
                                axisRenderer.draw(frame, frozenMatrix)
                            }
                        }
                    }
                }

                updateModelTransforms()
                modelRenderer.updateCamera(viewMatrix, projectionMatrix)
                modelRenderer.updateLightEstimate(frame.lightEstimate)
            } catch (e: Exception) {
                // Ignore frame update errors when session is paused
            }
        }
    }

    private fun ensureFilamentOverlay() {
        if (filamentTextureView != null) return
        filamentTextureView = TextureView(viewContext).apply {
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
            isOpaque = false
        }
        rootView.addView(filamentTextureView)
        filamentTextureView?.let { modelRenderer.attachTextureView(it) }
    }

    private data class SimpleNode(
        val name: String,
        var transformation: ArrayList<Double>,
        val type: Int,
        val uri: String,
        var anchorName: String?
    )

    /// Spec video marker yang menunggu surface GL siap.
    private data class PendingMarkerVideo(
        val videoPath: String,
        val kind: String,
        val loop: Boolean,
        val muted: Boolean,
        val autoplay: Boolean,
    )

}


