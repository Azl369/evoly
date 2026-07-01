package com.evoly.app

import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        preferHighestRefreshRate()
    }

    private fun preferHighestRefreshRate() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return
        }

        val supportedModes = window.windowManager.defaultDisplay.supportedModes
        val fastestMode = supportedModes.maxByOrNull { mode ->
            mode.refreshRate
        } ?: return

        window.attributes = window.attributes.apply {
            preferredDisplayModeId = fastestMode.modeId
        }
    }
}
