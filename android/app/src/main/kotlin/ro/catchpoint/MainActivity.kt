package ro.catchpoint

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ro.catchpoint/api")
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"getApiKey" -> {
						try {
							val ai = applicationContext.packageManager.getApplicationInfo(
								applicationContext.packageName,
								PackageManager.GET_META_DATA
							)
							val bundle = ai.metaData
							val key = bundle?.getString("com.google.android.geo.API_KEY")
							if (key != null) result.success(key) else result.error("NO_KEY", "API key not found", null)
						} catch (e: Exception) {
							result.error("ERROR", e.message, null)
						}
					}
					"getDirectionsApiKey" -> {
						try {
							val ai = applicationContext.packageManager.getApplicationInfo(
								applicationContext.packageName,
								PackageManager.GET_META_DATA
							)
							val bundle = ai.metaData
							val key = bundle?.getString("ro.catchpoint.DIRECTIONS_API_KEY")
							if (key != null) result.success(key) else result.error("NO_KEY", "Directions API key not found", null)
						} catch (e: Exception) {
							result.error("ERROR", e.message, null)
						}
					}
					else -> result.notImplemented()
				}
			}
	}
}
