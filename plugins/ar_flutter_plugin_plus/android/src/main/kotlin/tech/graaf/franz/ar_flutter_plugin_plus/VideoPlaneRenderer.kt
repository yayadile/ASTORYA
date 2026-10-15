package tech.graaf.franz.ar_flutter_plugin_plus

import android.graphics.SurfaceTexture
import android.opengl.GLES11Ext
import android.opengl.GLES20
import android.util.Log
import java.nio.ByteBuffer
import java.nio.ByteOrder

/// Quad video OpenGL yang digambar tepat di atas bidang marker, per frame.
///
/// Dipakai mode native "video-on-marker" untuk `meshplane.glb`: mesh tersebut
/// memang sebuah plane, jadi alih-alih memaksa tekstur video eksternal (OES)
/// ke material glTF Filament (yang mendeklarasikan `sampler2D` sehingga akan
/// render hitam), video digambar langsung sebagai textured quad. Posisi quad
/// dihitung dari 4 sudut layar marker ARCore setiap frame
/// ([AndroidARView.computeMarkerScreenCorners]), sehingga video mengikuti
/// perspektif/posisi/skala marker secara beneran (tracking 3D per-frame,
/// bukan overlay widget).
///
/// Frame video disuplai [MediaPlayer] (dikelola [AndroidARView]) lewat
/// [SurfaceTexture] milik renderer ini.
internal class VideoPlaneRenderer {
    private val TAG = "VideoPlaneRenderer"

    private var program = 0
    private var aPos = -1
    private var aTex = -1
    private var uTex = -1
    private var oesTexId = 0

    /// SurfaceTexture sumber frame. Dibuat di GL thread ([initialize]).
    var surfaceTexture: SurfaceTexture? = null
        private set

    fun isReady(): Boolean = program != 0 && surfaceTexture != null

    /// Wajib dipanggil di GL thread (dari `onSurfaceCreated`).
    fun initialize(): Boolean {
        if (program != 0) return true
        val vs = compileShader(GLES20.GL_VERTEX_SHADER, VERTEX_SHADER)
        val fs = compileShader(GLES20.GL_FRAGMENT_SHADER, FRAGMENT_SHADER)
        if (vs == 0 || fs == 0) return false

        program = GLES20.glCreateProgram()
        GLES20.glAttachShader(program, vs)
        GLES20.glAttachShader(program, fs)
        GLES20.glLinkProgram(program)
        val linked = IntArray(1)
        GLES20.glGetProgramiv(program, GLES20.GL_LINK_STATUS, linked, 0)
        if (linked[0] == 0) {
            Log.e(TAG, "link program: ${GLES20.glGetProgramInfoLog(program)}")
            GLES20.glDeleteProgram(program)
            program = 0
            return false
        }
        aPos = GLES20.glGetAttribLocation(program, "aPos")
        aTex = GLES20.glGetAttribLocation(program, "aTex")
        uTex = GLES20.glGetUniformLocation(program, "uTex")

        val ids = IntArray(1)
        GLES20.glGenTextures(1, ids, 0)
        oesTexId = ids[0]
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, oesTexId)
        GLES20.glTexParameteri(
            GLES11Ext.GL_TEXTURE_EXTERNAL_OES,
            GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(
            GLES11Ext.GL_TEXTURE_EXTERNAL_OES,
            GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(
            GLES11Ext.GL_TEXTURE_EXTERNAL_OES,
            GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
        GLES20.glTexParameteri(
            GLES11Ext.GL_TEXTURE_EXTERNAL_OES,
            GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)

        val st = SurfaceTexture(oesTexId)
        surfaceTexture = st
        return true
    }

    /// Gambar frame video terbaru pada quad [cornersNorm] (8 double ternor-
    /// malisasi [0,1], urutan TL, TR, BR, BL). Wajib di GL thread.
    /// Mengembalikan `true` bila quad benar-benar di-submit ke GL.
    /// Tidak menggambar apa pun bila frame belum ada / surface dilepas.
    ///
    /// [rotationDegrees] memutar konten video searah jarum jam (0/90/180/
    /// 270) untuk menyamakan orientasi cetak marker: sudut layar `i`
    /// menampilkan konten sudut `(i - rot)`.
    fun draw(
        cornersNorm: DoubleArray,
        rotationDegrees: Int = 0,
        mirror: Boolean = false,
    ): Boolean {
        if (cornersNorm.size != 8) return false
        if (program == 0 || oesTexId == 0) return false
        val tm = latchFrame() ?: return false
        val rot = normRot(rotationDegrees)

        val pos = FloatArray(8)
        for (i in 0 until 4) {
            val nx = cornersNorm[i * 2].toFloat()
            val ny = cornersNorm[i * 2 + 1].toFloat()
            pos[i * 2] = nx * 2f - 1f
            pos[i * 2 + 1] = 1f - ny * 2f
        }
        val uv = FloatArray(8)
        fillUv(uv, rot, tm, mirror)
        submit(pos, uv)
        return true
    }

    /// Gambar video menutupi layar (mode fullscreen): persegi contain-fit
    /// di tengah viewport NDC. Dipakai halaman fullscreen Flutter yang
    /// transparan - player-nya TETAP milik native sehingga tidak ada
    /// perebutan audio focus dengan Voiceover/BGM.
    ///
    /// [vpW]/[vpH]: ukuran viewport piksel. [aspect]: aspek video (w/h).
    fun drawFullscreen(
        vpW: Int,
        vpH: Int,
        aspect: Float,
        rotationDegrees: Int = 0,
        mirror: Boolean = false,
    ): Boolean {
        if (program == 0 || oesTexId == 0) return false
        if (vpW <= 0 || vpH <= 0) return false
        val safeAspect = if (aspect > 0f) aspect else 16f / 9f
        val tm = latchFrame() ?: return false
        val rot = normRot(rotationDegrees)

        val viewAspect = vpW.toFloat() / vpH.toFloat()
        val rw = 2f * minOf(1f, safeAspect / viewAspect)
        val rh = 2f * minOf(1f, viewAspect / safeAspect)
        val pos = floatArrayOf(
            -rw / 2f, rh / 2f, // TL
            rw / 2f, rh / 2f, // TR
            rw / 2f, -rh / 2f, // BR
            -rw / 2f, -rh / 2f, // BL
        )
        val uv = FloatArray(8)
        fillUv(uv, rot, tm, mirror)
        submit(pos, uv)
        return true
    }

    private fun normRot(rotationDegrees: Int): Int =
        ((rotationDegrees / 90) % 4 + 4) % 4

    /// Ambil frame terbaru + matriks transform. Null bila gagal.
    private fun latchFrame(): FloatArray? {
        val st = surfaceTexture ?: return null
        try {
            st.updateTexImage()
        } catch (_: Exception) {
            return null // surface ditinggalkan MediaPlayer
        }
        val tm = FloatArray(16)
        try {
            st.getTransformMatrix(tm)
        } catch (_: Exception) {
            return null
        }
        return tm
    }

    /// Isi UV video: TL=(0,0) TR=(1,0) BR=(1,1) BL=(0,1), ditransform
    /// matriks SurfaceTexture (rotasi frame kamera). [mirror] membalik
    /// sumbu-U (koreksi efek kaca).
    private fun fillUv(uv: FloatArray, rot: Int, tm: FloatArray, mirror: Boolean) {
        for (i in 0 until 4) {
            val ui = (i - rot + 4) % 4
            val u0 = if (ui == 0 || ui == 3) 0f else 1f
            val u = if (mirror) 1f - u0 else u0
            val v = if (ui < 2) 0f else 1f
            uv[i * 2] = tm[0] * u + tm[4] * v + tm[12]
            uv[i * 2 + 1] = tm[1] * u + tm[5] * v + tm[13]
        }
    }

    private fun submit(pos: FloatArray, uv: FloatArray) {
        val posBuf = ByteBuffer.allocateDirect(32)
            .order(ByteOrder.nativeOrder()).asFloatBuffer()
        posBuf.put(pos).position(0)
        val uvBuf = ByteBuffer.allocateDirect(32)
            .order(ByteOrder.nativeOrder()).asFloatBuffer()
        uvBuf.put(uv).position(0)

        GLES20.glDisable(GLES20.GL_DEPTH_TEST)
        GLES20.glUseProgram(program)
        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, oesTexId)
        GLES20.glUniform1i(uTex, 0)

        GLES20.glEnableVertexAttribArray(aPos)
        GLES20.glVertexAttribPointer(aPos, 2, GLES20.GL_FLOAT, false, 0, posBuf)
        GLES20.glEnableVertexAttribArray(aTex)
        GLES20.glVertexAttribPointer(aTex, 2, GLES20.GL_FLOAT, false, 0, uvBuf)
        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_FAN, 0, 4)
        GLES20.glDisableVertexAttribArray(aPos)
        GLES20.glDisableVertexAttribArray(aTex)
        GLES20.glEnable(GLES20.GL_DEPTH_TEST)
    }

    /// Bebaskan tekstur/program. SurfaceTexture dilepas di sini; aman
    /// dipanggil dari thread mana pun (atas kegagalan di-catch).
    fun release() {
        try {
            surfaceTexture?.release()
        } catch (_: Exception) {
        }
        surfaceTexture = null
        // glDelete* butuh konteks GL; hanya coba bila program ada.
        try {
            if (oesTexId != 0) {
                GLES20.glDeleteTextures(1, intArrayOf(oesTexId), 0)
            }
            if (program != 0) {
                GLES20.glDeleteProgram(program)
            }
        } catch (_: Exception) {
        }
        oesTexId = 0
        program = 0
    }

    private fun compileShader(type: Int, src: String): Int {
        val s = GLES20.glCreateShader(type)
        GLES20.glShaderSource(s, src)
        GLES20.glCompileShader(s)
        val status = IntArray(1)
        GLES20.glGetShaderiv(s, GLES20.GL_COMPILE_STATUS, status, 0)
        if (status[0] == 0) {
            Log.e(TAG, "compile shader: ${GLES20.glGetShaderInfoLog(s)}")
            GLES20.glDeleteShader(s)
            return 0
        }
        return s
    }

    companion object {
        private const val VERTEX_SHADER = """
            attribute vec4 aPos;
            attribute vec2 aTex;
            varying vec2 vTex;
            void main() {
                gl_Position = aPos;
                vTex = aTex;
            }
        """
        private const val FRAGMENT_SHADER = """
            #extension GL_OES_EGL_image_external : require
            precision mediump float;
            varying vec2 vTex;
            uniform samplerExternalOES uTex;
            void main() {
                gl_FragColor = texture2D(uTex, vTex);
            }
        """
    }
}
