package com.termux.shared.termux.shell;

import android.content.Context;
import android.content.res.AssetManager;
import android.system.Os;

import com.termux.shared.file.FileUtils;
import com.termux.shared.logger.Logger;
import com.termux.shared.termux.TermuxConstants;

import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;

/**
 * Utility for executing binaries stored in APK assets
 * Complies with Android 10+ exec policy by extracting to app-private storage only when needed
 */
public class TermuxAssetExecutor {

    private static final String LOG_TAG = "TermuxAssetExecutor";
    
    /**
     * Extract executable from assets to temporary location and return executable path
     * @param context Application context to access assets
     * @param assetPath Path to executable in assets (e.g., "executables/login")
     * @param executableName Name of the executable for temp file
     * @return Absolute path to extracted executable, or null if extraction failed
     */
    public static String extractAndPrepareExecutable(Context context, String assetPath, String executableName) {
        try {
            // Create temp directory in app-private storage
            File tempDir = new File(TermuxConstants.TERMUX_TMP_PREFIX_DIR_PATH, "assets-exec");
            FileUtils.createDirectoryFile(tempDir.getAbsolutePath());
            
            File tempExecutable = new File(tempDir, executableName);
            
            // Extract from assets
            AssetManager assets = context.getAssets();
            try (InputStream assetStream = assets.open(assetPath);
                 FileOutputStream fos = new FileOutputStream(tempExecutable)) {
                
                byte[] buffer = new byte[8192];
                int bytesRead;
                while ((bytesRead = assetStream.read(buffer)) != -1) {
                    fos.write(buffer, 0, bytesRead);
                }
            }
            
            // Set executable permissions
            //noinspection OctalInteger
            Os.chmod(tempExecutable.getAbsolutePath(), 0700);
            
            Logger.logInfo(LOG_TAG, "Extracted " + executableName + " from assets to temporary location: " + tempExecutable.getAbsolutePath());
            return tempExecutable.getAbsolutePath();
            
        } catch (Exception e) {
            Logger.logStackTraceWithMessage(LOG_TAG, "Failed to extract asset executable " + executableName, e);
            return null;
        }
    }
    
    /**
     * Check if an executable exists in assets
     * @param context Application context
     * @param executableName Name of executable to check
     * @return true if executable exists in assets
     */
    public static boolean hasAssetExecutable(Context context, String executableName) {
        try {
            InputStream stream = context.getAssets().open(TermuxConstants.TERMUX_ASSETS_EXECUTABLES_PATH + "/" + executableName);
            stream.close();
            return true;
        } catch (Exception e) {
            return false;
        }
    }
}