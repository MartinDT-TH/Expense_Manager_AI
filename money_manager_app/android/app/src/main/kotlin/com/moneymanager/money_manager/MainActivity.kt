package com.moneymanager.money_manager

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Fix BLASTBufferQueue error by ensuring proper surface handling
        intent.putExtra("background_mode", BackgroundMode.opaque.toString())
        super.onCreate(savedInstanceState)
    }

    // Use opaque background mode to reduce buffer issues
    override fun getBackgroundMode(): BackgroundMode {
        return BackgroundMode.opaque
    }
}
