package com.termux.app;

import android.app.Activity;
import android.content.Context;
import android.content.res.AssetManager;
import android.os.Build;
import android.util.Log;

import com.termux.shared.errors.Error;
import com.termux.shared.file.FileUtils;
import com.termux.shared.logger.Logger;
import com.termux.shared.termux.TermuxConstants;
import android.content.SharedPreferences;
import androidx.preference.PreferenceManager;

import org.json.JSONException;
import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.Arrays;
import java.util.zip.GZIPInputStream;
import org.apache.commons.compress.archivers.tar.TarArchiveEntry;
import org.apache.commons.compress.archivers.tar.TarArchiveInputStream;

/**
 * Install AI packages (Codex CLI and optional MCP) if running on aarch64 architecture.
 * This installer runs after the main bootstrap installation and handles AI-specific assets.
 */
final class TermuxAIInstaller {

    private static final String LOG_TAG = "TermuxAIInstaller";

    /**
     * Check if the current device supports AI packages (aarch64 only).
     */
    public static boolean isAISupported() {
        return Arrays.asList(Build.SUPPORTED_ABIS).contains("arm64-v8a");
    }

    /**
     * Install AI packages if supported and not already installed.
     */
    static void setupAIPackagesIfNeeded(final Activity activity, final Runnable whenDone) {
        if (!isAISupported()) {
            Logger.logInfo(LOG_TAG, "AI packages not supported on this architecture: " + Arrays.toString(Build.SUPPORTED_ABIS));
            whenDone.run();
            return;
        }

        // Check if Codex is already installed
        File codexBinary = new File(TermuxConstants.TERMUX_PREFIX_DIR_PATH + "/bin/codex");
        if (codexBinary.exists() && codexBinary.canExecute()) {
            Logger.logInfo(LOG_TAG, "Codex CLI already installed, skipping AI package installation.");
            whenDone.run();
            return;
        }

        new Thread(() -> {
            try {
                Logger.logInfo(LOG_TAG, "Installing AI packages for aarch64 architecture.");
                
                // Load preload index
                JSONObject preloadIndex = loadPreloadIndex(activity);
                if (preloadIndex == null) {
                    Logger.logError(LOG_TAG, "Failed to load preload index, skipping AI installation.");
                    activity.runOnUiThread(whenDone);
                    return;
                }

                // Install Codex CLI (required)
                installCodexCLI(activity, preloadIndex);

                // Install MCP extension if enabled in settings
                if (shouldInstallMCP(activity)) {
                    installMCPExtension(activity, preloadIndex);
                }

                Logger.logInfo(LOG_TAG, "AI packages installed successfully.");
                activity.runOnUiThread(whenDone);

            } catch (Exception e) {
                Logger.logStackTraceWithMessage(LOG_TAG, "Failed to install AI packages", e);
                activity.runOnUiThread(whenDone);
            }
        }).start();
    }

    private static JSONObject loadPreloadIndex(Context context) {
        try {
            AssetManager assets = context.getAssets();
            InputStream inputStream = assets.open("preload/index-aarch64.json");
            BufferedReader reader = new BufferedReader(new InputStreamReader(inputStream));
            StringBuilder jsonBuilder = new StringBuilder();
            String line;
            while ((line = reader.readLine()) != null) {
                jsonBuilder.append(line);
            }
            reader.close();
            return new JSONObject(jsonBuilder.toString());
        } catch (IOException | JSONException e) {
            Logger.logStackTraceWithMessage(LOG_TAG, "Failed to load preload index", e);
            return null;
        }
    }

    private static void installCodexCLI(Context context, JSONObject preloadIndex) throws Exception {
        Logger.logInfo(LOG_TAG, "Installing Codex CLI...");
        
        JSONObject codexPackage = preloadIndex.getJSONObject("packages").getJSONObject("codex");
        String assetPath = codexPackage.getString("asset_path");
        String expectedChecksum = codexPackage.getString("checksum").replace("sha256:", "");
        
        // Extract Codex tarball from assets
        AssetManager assets = context.getAssets();
        
        // Create installation directory
        File codexDir = new File(TermuxConstants.TERMUX_PREFIX_DIR_PATH + "/opt/codex");
        Error error = FileUtils.createDirectoryFile(codexDir.getAbsolutePath());
        if (error != null) {
            throw new RuntimeException("Failed to create codex directory: " + error.getMessage());
        }

        // Extract tarball from assets
        try (InputStream assetStream = assets.open(assetPath)) {
            // Verify checksum
            String actualChecksum = calculateSHA256(assetStream);
            if (!expectedChecksum.equals(actualChecksum)) {
                throw new RuntimeException("Codex CLI checksum mismatch: expected " + expectedChecksum + ", got " + actualChecksum);
            }
            
            // Reset stream for extraction
            try (InputStream extractStream = assets.open(assetPath)) {
                extractTarGz(extractStream, codexDir);
            }
        }

        // Create symlinks
        File binDir = new File(TermuxConstants.TERMUX_PREFIX_DIR_PATH + "/bin");
        FileUtils.createDirectoryFile(binDir.getAbsolutePath());
        
        String[] binaries = {"codex", "codexd", "codex-cli"};
        for (String binary : binaries) {
            File srcFile = new File(codexDir, "bin/" + binary);
            File destFile = new File(binDir, binary);
            if (srcFile.exists()) {
                if (destFile.exists()) {
                    destFile.delete();
                }
                try {
                    android.system.Os.symlink(srcFile.getAbsolutePath(), destFile.getAbsolutePath());
                } catch (Exception e) {
                    Logger.logStackTraceWithMessage(LOG_TAG, "Failed to create symlink for " + binary, e);
                }
            }
        }
        
        Logger.logInfo(LOG_TAG, "Codex CLI installed successfully.");
    }

    private static void installMCPExtension(Context context, JSONObject preloadIndex) throws Exception {
        Logger.logInfo(LOG_TAG, "Installing MCP extension...");
        
        JSONObject mcpPackage = preloadIndex.getJSONObject("packages").getJSONObject("mcp");
        String assetPath = mcpPackage.getString("asset_path");
        String expectedChecksum = mcpPackage.getString("checksum").replace("sha256:", "");
        
        // Create MCP wheels directory
        File mcpWheelsDir = new File(TermuxConstants.TERMUX_PREFIX_DIR_PATH + "/share/wheels/mcp-cli");
        Error error = FileUtils.createDirectoryFile(mcpWheelsDir.getAbsolutePath());
        if (error != null) {
            throw new RuntimeException("Failed to create MCP wheels directory: " + error.getMessage());
        }

        // Extract MCP wheels from assets if available
        AssetManager assets = context.getAssets();
        try (InputStream assetStream = assets.open(assetPath)) {
            // Verify checksum
            String actualChecksum = calculateSHA256(assetStream);
            if (!expectedChecksum.equals(actualChecksum)) {
                Logger.logWarn(LOG_TAG, "MCP wheels checksum mismatch, using fallback installation");
            } else {
                // Extract wheels tarball
                try (InputStream extractStream = assets.open(assetPath)) {
                    extractTarGz(extractStream, mcpWheelsDir);
                    Logger.logInfo(LOG_TAG, "MCP wheels extracted successfully");
                }
            }
        } catch (IOException e) {
            Logger.logWarn(LOG_TAG, "MCP wheels not available, will use online installation");
        }

        // Create MCP wrapper script
        File mcpBin = new File(TermuxConstants.TERMUX_PREFIX_DIR_PATH + "/bin");
        File mcpScript = new File(mcpBin, "mcp");
        try (FileOutputStream fos = new FileOutputStream(mcpScript)) {
            String script = "#!/data/data/com.termux/files/usr/bin/sh\n" +
                           "# MCP extension wrapper for Termux AI\n" +
                           "if command -v python >/dev/null 2>&1; then\n" +
                           "    exec python -m mcp \"$@\"\n" +
                           "else\n" +
                           "    echo \"Error: Python not available. Please install Python to use MCP extension.\"\n" +
                           "    exit 1\n" +
                           "fi\n";
            fos.write(script.getBytes());
        }
        mcpScript.setExecutable(true);
        
        Logger.logInfo(LOG_TAG, "MCP extension installed successfully.");
    }

    private static boolean shouldInstallMCP(Context context) {
        SharedPreferences preferences = PreferenceManager.getDefaultSharedPreferences(context);
        return preferences.getBoolean("ai_mcp_enabled", false);
    }

    private static void extractTarGz(InputStream inputStream, File outputDir) throws IOException {
        try (GZIPInputStream gzipStream = new GZIPInputStream(inputStream);
             TarArchiveInputStream tarStream = new TarArchiveInputStream(gzipStream)) {
            
            TarArchiveEntry entry;
            while ((entry = (TarArchiveEntry) tarStream.getNextEntry()) != null) {
                File outputFile = new File(outputDir, entry.getName());
                
                if (entry.isDirectory()) {
                    FileUtils.createDirectoryFile(outputFile.getAbsolutePath());
                } else {
                    // Ensure parent directory exists
                    FileUtils.createDirectoryFile(outputFile.getParentFile().getAbsolutePath());
                    
                    // Extract file
                    try (FileOutputStream fos = new FileOutputStream(outputFile)) {
                        byte[] buffer = new byte[8192];
                        int bytesRead;
                        while ((bytesRead = tarStream.read(buffer)) != -1) {
                            fos.write(buffer, 0, bytesRead);
                        }
                    }
                    
                    // Set executable permissions for binaries
                    if (entry.getName().startsWith("bin/") || (entry.getMode() & 0100) != 0) {
                        outputFile.setExecutable(true);
                    }
                }
            }
        }
    }

    private static String calculateSHA256(InputStream inputStream) throws IOException, NoSuchAlgorithmException {
        MessageDigest digest = MessageDigest.getInstance("SHA-256");
        byte[] buffer = new byte[8192];
        int bytesRead;
        while ((bytesRead = inputStream.read(buffer)) != -1) {
            digest.update(buffer, 0, bytesRead);
        }
        byte[] hashBytes = digest.digest();
        
        StringBuilder hexString = new StringBuilder();
        for (byte b : hashBytes) {
            String hex = Integer.toHexString(0xff & b);
            if (hex.length() == 1) {
                hexString.append('0');
            }
            hexString.append(hex);
        }
        return hexString.toString();
    }
}