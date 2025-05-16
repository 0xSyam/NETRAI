package com.netrai.app.view

import android.content.Context
import android.graphics.PixelFormat
import android.os.Build
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import com.netrai.app.R

class ScreenShareFloatingView(private val context: Context) {
    private var windowManager: WindowManager? = null
    private var floatingView: View? = null
    private var params: WindowManager.LayoutParams? = null
    private var isShowing = false

    private var onStopShareClickListener: (() -> Unit)? = null
    private var onSpeakToNetraiClickListener: (() -> Unit)? = null

    init {
        windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        
        // Inflate the layout
        floatingView = LayoutInflater.from(context).inflate(R.layout.floating_screen_share, null)
        
        // Set up click listeners
        val btnSpeakToNetrai = floatingView?.findViewById<Button>(R.id.btnSpeakToNetrai)
        val btnStopShare = floatingView?.findViewById<Button>(R.id.btnStopShare)
        
        btnSpeakToNetrai?.setOnClickListener {
            onSpeakToNetraiClickListener?.invoke()
        }
        
        btnStopShare?.setOnClickListener {
            onStopShareClickListener?.invoke()
        }
        
        // Initialize layout params
        params = WindowManager.LayoutParams().apply {
            // Choose the appropriate type based on Android version
            type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                WindowManager.LayoutParams.TYPE_PHONE
            }
            
            // Set other params
            flags = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
            format = PixelFormat.TRANSLUCENT
            width = WindowManager.LayoutParams.WRAP_CONTENT
            height = WindowManager.LayoutParams.WRAP_CONTENT
            gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL // Default ke tengah bawah
        }
    }
    
    fun setOnStopShareClickListener(listener: () -> Unit) {
        onStopShareClickListener = listener
    }
    
    fun setOnSpeakToNetraiClickListener(listener: () -> Unit) {
        onSpeakToNetraiClickListener = listener
    }
    
    fun show(gravity: Int = Gravity.CENTER, width: Int = WindowManager.LayoutParams.WRAP_CONTENT, height: Int = WindowManager.LayoutParams.WRAP_CONTENT) {
        if (isShowing) return
        
        try {
            // Update params if needed
            params?.gravity = gravity
            params?.width = width
            params?.height = height
            
            // Add the view to window manager
            windowManager?.addView(floatingView, params)
            isShowing = true
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
    
    fun hide() {
        if (!isShowing || floatingView == null) return
        
        try {
            windowManager?.removeView(floatingView)
            isShowing = false
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
    
    fun isFloatingViewShowing(): Boolean {
        return isShowing
    }
} 