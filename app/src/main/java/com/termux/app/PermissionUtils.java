package com.termux.app;

import android.Manifest;
import android.app.Activity;
import android.content.pm.PackageManager;
import android.os.Build;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

import com.termux.shared.logger.Logger;

/**
 * Utility class for handling Android 13+ notification permissions and other runtime permissions.
 */
public class PermissionUtils {

    private static final String LOG_TAG = "PermissionUtils";
    private static final int REQUEST_POST_NOTIFICATIONS = 1001;

    /**
     * Check if notification permission is required and granted.
     */
    public static boolean isNotificationPermissionGranted(Activity activity) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            return ContextCompat.checkSelfPermission(activity, Manifest.permission.POST_NOTIFICATIONS) 
                   == PackageManager.PERMISSION_GRANTED;
        }
        return true; // Not required on Android < 13
    }

    /**
     * Request notification permission if needed (Android 13+).
     */
    public static void requestNotificationPermissionIfNeeded(Activity activity) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (!isNotificationPermissionGranted(activity)) {
                Logger.logInfo(LOG_TAG, "Requesting POST_NOTIFICATIONS permission for Android 13+");
                ActivityCompat.requestPermissions(activity, 
                    new String[]{Manifest.permission.POST_NOTIFICATIONS}, 
                    REQUEST_POST_NOTIFICATIONS);
            }
        }
    }

    /**
     * Handle permission request result for notification permission.
     */
    public static boolean handleNotificationPermissionResult(int requestCode, String[] permissions, int[] grantResults) {
        if (requestCode == REQUEST_POST_NOTIFICATIONS) {
            if (grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                Logger.logInfo(LOG_TAG, "POST_NOTIFICATIONS permission granted");
                return true;
            } else {
                Logger.logInfo(LOG_TAG, "POST_NOTIFICATIONS permission denied");
                return false;
            }
        }
        return false;
    }
}