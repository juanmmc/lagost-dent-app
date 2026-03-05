package com.example.frontend

import com.mr.flutter.plugin.filepicker.FilePickerPlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		// Defensive manual registration in case automatic plugin registration fails.
		if (!flutterEngine.plugins.has(FilePickerPlugin::class.java)) {
			flutterEngine.plugins.add(FilePickerPlugin())
		}
	}
}
