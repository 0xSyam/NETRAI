package com.netrai.app

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.view.Gravity
import android.view.WindowManager
import android.widget.Toast
import com.netrai.app.view.ScreenShareFloatingView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class OverlayModule(private val activity: Activity) : MethodCallHandler {
    companion object {
        private const val CHANNEL_NAME = "com.netrai/overlay"
        
        fun registerWith(flutterEngine: FlutterEngine, activity: Activity) {
            val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
            channel.setMethodCallHandler(OverlayModule(activity))
        }
    }
    
    private var floatingView: ScreenShareFloatingView? = null
    private var stopShareCallback: MethodChannel.Result? = null
    private var speakToNetraiCallback: MethodChannel.Result? = null
    
    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "initializeOverlay" -> {
                initialize()
                result.success(true)
            }
            "showOverlay" -> {
                val width = call.argument<Int>("width") ?: WindowManager.LayoutParams.WRAP_CONTENT
                val height = call.argument<Int>("height") ?: WindowManager.LayoutParams.WRAP_CONTENT
                val gravityString = call.argument<String>("gravity") ?: "center"
                
                val gravity = when (gravityString) {
                    "top" -> Gravity.TOP or Gravity.CENTER_HORIZONTAL
                    "bottom" -> Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL
                    "left" -> Gravity.CENTER_VERTICAL or Gravity.START
                    "right" -> Gravity.CENTER_VERTICAL or Gravity.END
                    "top_left" -> Gravity.TOP or Gravity.START
                    "top_right" -> Gravity.TOP or Gravity.END
                    "bottom_left" -> Gravity.BOTTOM or Gravity.START
                    "bottom_right" -> Gravity.BOTTOM or Gravity.END
                    else -> Gravity.CENTER // Default is center
                }
                
                // Cek izin overlay terlebih dahulu
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(activity)) {
                    // Tampilkan pesan toast bahwa izin diperlukan
                    activity.runOnUiThread {
                        Toast.makeText(activity, "Izin tampilan di atas aplikasi lain diperlukan", Toast.LENGTH_LONG).show()
                    }
                    
                    // Buka pengaturan overlay
                    openOverlaySettings()
                    result.success(false)
                    return
                }
                
                result.success(showOverlay(gravity, width, height))
            }
            "hideOverlay" -> {
                result.success(hideOverlay())
            }
            "onStopSharePressed" -> {
                stopShareCallback = result
            }
            "onSpeakToNetraiPressed" -> {
                speakToNetraiCallback = result
            }
            "openOverlaySettings" -> {
                // Tampilkan pesan toast saat membuka pengaturan overlay
                activity.runOnUiThread {
                    Toast.makeText(activity, "Harap aktifkan 'Tampilkan di atas aplikasi lain'", Toast.LENGTH_LONG).show()
                }
                result.success(openOverlaySettings())
            }
            "checkOverlayPermission" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    result.success(Settings.canDrawOverlays(activity))
                } else {
                    result.success(true) // Untuk versi Android < M, selalu true
                }
            }
            else -> {
                result.notImplemented()
            }
        }
    }
    
    private fun initialize() {
        if (floatingView == null) {
            floatingView = ScreenShareFloatingView(activity.applicationContext)
            
            // Set up click listeners
            floatingView?.setOnStopShareClickListener {
                val callback = stopShareCallback
                stopShareCallback = null
                callback?.success(true)
                
                // Auto hide the overlay
                hideOverlay()
            }
            
            floatingView?.setOnSpeakToNetraiClickListener {
                val callback = speakToNetraiCallback
                speakToNetraiCallback = null
                callback?.success(true)
            }
        }
    }
    
    private fun showOverlay(gravity: Int, width: Int, height: Int): Boolean {
        try {
            if (floatingView == null) {
                initialize()
            }
            
            activity.runOnUiThread {
                floatingView?.show(gravity, width, height)
            }
            
            return true
        } catch (e: Exception) {
            e.printStackTrace()
            return false
        }
    }
    
    private fun hideOverlay(): Boolean {
        try {
            activity.runOnUiThread {
                floatingView?.hide()
            }
            return true
        } catch (e: Exception) {
            e.printStackTrace()
            return false
        }
    }
    
    private fun openOverlaySettings(): Boolean {
        try {
            // Buka pengaturan overlay window secara langsung
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                // Pastikan intent benar-benar membuka halaman izin overlay
                val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION)
                intent.data = Uri.parse("package:${activity.packageName}")
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                
                // Tampilkan toast untuk petunjuk
                activity.runOnUiThread {
                    Toast.makeText(activity, "Aktifkan 'Tampilkan di atas aplikasi lain' untuk NetrAI", Toast.LENGTH_LONG).show()
                }
                
                activity.startActivity(intent)
            } else {
                // Untuk versi Android sebelumnya, tidak ada pengaturan khusus
                val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                intent.data = Uri.parse("package:${activity.packageName}")
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                activity.startActivity(intent)
            }
            return true
        } catch (e: Exception) {
            e.printStackTrace()
            
            // Fallback jika intent langsung gagal
            try {
                val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                intent.data = Uri.parse("package:${activity.packageName}")
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                activity.startActivity(intent)
            } catch (e2: Exception) {
                e2.printStackTrace()
                return false
            }
            
            return false
        }
    }
} 