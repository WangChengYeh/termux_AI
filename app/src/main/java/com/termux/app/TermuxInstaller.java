package com.termux.app;

import android.app.Activity;
import android.app.AlertDialog;
import android.app.ProgressDialog;
import android.content.Context;
import android.os.Build;
import android.os.Environment;
import android.system.Os;
import android.view.WindowManager;

import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;

import com.termux.R;
import com.termux.shared.file.FileUtils;
import com.termux.shared.termux.crash.TermuxCrashUtils;
import com.termux.shared.termux.file.TermuxFileUtils;
import com.termux.shared.interact.MessageDialogUtils;
import com.termux.shared.logger.Logger;
import com.termux.shared.markdown.MarkdownUtils;
import com.termux.shared.errors.Error;
import com.termux.shared.android.PackageUtils;
import com.termux.shared.termux.TermuxConstants;
import com.termux.shared.termux.TermuxUtils;
import com.termux.shared.termux.shell.command.environment.TermuxShellEnvironment;

import static com.termux.shared.termux.TermuxConstants.TERMUX_PREFIX_DIR;
import static com.termux.shared.termux.TermuxConstants.TERMUX_PREFIX_DIR_PATH;
import static com.termux.shared.termux.TermuxConstants.TERMUX_STAGING_PREFIX_DIR;
import static com.termux.shared.termux.TermuxConstants.TERMUX_STAGING_PREFIX_DIR_PATH;

/**
 * Install the Termux bootstrap packages if necessary by following the below steps:
 * <p/>
 * (1) If $PREFIX already exist, assume that it is correct and be done. Note that this relies on that we do not create a
 * broken $PREFIX directory below.
 * <p/>
 * (2) A progress dialog is shown with "Installing..." message and a spinner.
 * <p/>
 * (3) A staging directory, $STAGING_PREFIX, is cleared if left over from broken installation below.
 * <p/>
 * (4) The zip file is loaded from a shared library.
 * <p/>
 * (5) The zip, containing entries relative to the $PREFIX, is is downloaded and extracted by a zip input stream
 * continuously encountering zip file entries:
 * <p/>
 * (5.1) If the zip entry encountered is SYMLINKS.txt, go through it and remember all symlinks to setup.
 * <p/>
 * (5.2) For every other zip entry, extract it into $STAGING_PREFIX and set execute permissions if necessary.
 */
final class TermuxInstaller {

    private static final String LOG_TAG = "TermuxInstaller";

    /** Performs bootstrap setup if necessary. */
    static void setupBootstrapIfNeeded(final Activity activity, final Runnable whenDone) {
        String bootstrapErrorMessage;
        Error filesDirectoryAccessibleError;

        // This will also call Context.getFilesDir(), which should ensure that termux files directory
        // is created if it does not already exist
        filesDirectoryAccessibleError = TermuxFileUtils.isTermuxFilesDirectoryAccessible(activity, true, true);
        boolean isFilesDirectoryAccessible = filesDirectoryAccessibleError == null;

        // Termux can only be run as the primary user (device owner) since only that
        // account has the expected file system paths. Verify that:
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && !PackageUtils.isCurrentUserThePrimaryUser(activity)) {
            bootstrapErrorMessage = activity.getString(R.string.bootstrap_error_not_primary_user_message,
                MarkdownUtils.getMarkdownCodeForString(TERMUX_PREFIX_DIR_PATH, false));
            Logger.logError(LOG_TAG, "isFilesDirectoryAccessible: " + isFilesDirectoryAccessible);
            Logger.logError(LOG_TAG, bootstrapErrorMessage);
            sendBootstrapCrashReportNotification(activity, bootstrapErrorMessage);
            MessageDialogUtils.exitAppWithErrorMessage(activity,
                activity.getString(R.string.bootstrap_error_title),
                bootstrapErrorMessage);
            return;
        }

        if (!isFilesDirectoryAccessible) {
            bootstrapErrorMessage = Error.getMinimalErrorString(filesDirectoryAccessibleError);
            //noinspection SdCardPath
            if (PackageUtils.isAppInstalledOnExternalStorage(activity) &&
                !TermuxConstants.TERMUX_FILES_DIR_PATH.equals(activity.getFilesDir().getAbsolutePath().replaceAll("^/data/user/0/", "/data/data/"))) {
                bootstrapErrorMessage += "\n\n" + activity.getString(R.string.bootstrap_error_installed_on_portable_sd,
                    MarkdownUtils.getMarkdownCodeForString(TERMUX_PREFIX_DIR_PATH, false));
            }

            Logger.logError(LOG_TAG, bootstrapErrorMessage);
            sendBootstrapCrashReportNotification(activity, bootstrapErrorMessage);
            MessageDialogUtils.showMessage(activity,
                activity.getString(R.string.bootstrap_error_title),
                bootstrapErrorMessage, null);
            return;
        }

        // Create basic directory structure first
        FileUtils.createDirectoryFile(TERMUX_PREFIX_DIR_PATH);
        FileUtils.createDirectoryFile(TermuxConstants.TERMUX_HOME_DIR_PATH);
        FileUtils.createDirectoryFile(TermuxConstants.TERMUX_TMP_PREFIX_DIR_PATH);
        
        // Place native executables in /data/app read-only location
        Logger.logInfo(LOG_TAG, "Installing native executables to /data/app directory.");
        
        try {
            installNativeExecutables(activity);
        } catch (Exception e) {
            Logger.logError(LOG_TAG, "Failed to install native executables: " + e.getMessage());
            showBootstrapErrorDialog(activity, whenDone, "Failed to install native executables: " + e.getMessage());
            return;
        }
        
        // Write environment file
        TermuxShellEnvironment.writeEnvironmentToFile(activity);
        
        // Run the completion callback immediately
        activity.runOnUiThread(whenDone);
    }

    /**
     * Verify native executables are extracted and create symbolic links
     */
    private static void installNativeExecutables(Activity activity) throws Exception {
        // Native libs are automatically extracted to /data/app/{package}/lib/arm64/ 
        // by Android system when extractNativeLibs=true
        String nativeLibDir = activity.getApplicationInfo().nativeLibraryDir;
        Logger.logInfo(LOG_TAG, "Native libraries extracted to read-only location: " + nativeLibDir);
        
        // Create symbolic links for all native libraries
        createSymbolicLinks(activity, nativeLibDir);
        
        Logger.logInfo(LOG_TAG, "Native executables and libraries verified. Symbolic links created from: " + nativeLibDir);
    }
    
    /**
     * Create symbolic links for executables and libraries
     */
    private static void createSymbolicLinks(Activity activity, String nativeLibDir) throws Exception {
        // Create directories for symbolic links
        String binDir = TermuxConstants.TERMUX_BIN_PREFIX_DIR_PATH;
        String libDir = TermuxConstants.TERMUX_LIB_PREFIX_DIR_PATH;
        FileUtils.createDirectoryFile(binDir);
        FileUtils.createDirectoryFile(libDir);
        
        // Define executables that go to /usr/bin
        String[][] executables = {
            {"libcodex.so", "codex"},
            {"libcodex-exec.so", "codex-exec"},
            {"libapt.so", "apt"},
            {"libnode.so", "node"}
        };
        
        // Define libraries that go to /usr/lib
        String[][] libraries = {
            {"libandroid-glob.so", "libandroid-glob.so"},
            {"libapt-private.so", "libapt-private.so"},
            {"libapt-pkg.so", "libapt-pkg.so"},
            {"libc++_shared.so", "libc++_shared.so"},
            {"libzlib.so", "libz.so"},
            {"libz.so", "libz.so"},
            {"libz1.so", "libz.so.1"},
            {"libz131.so", "libz.so.1.3.1"},
            {"libcares.so", "libcares.so"},
            {"libbz2.so", "libbz2.so"},
            {"libbz210.so", "libbz2.so.1.0"},
            {"libsqlite3.so", "libsqlite3.so"},
            {"libsqlite3.so", "libsqlite3.so.0"},
            {"libcrypto3.so", "libcrypto.so.3"},
            {"libssl3.so", "libssl.so.3"},
            {"liblzma.so", "liblzma.so"},
            {"liblzma5.so", "liblzma.so.5"},
            {"liblzma581.so", "liblzma.so.5.8.1"},
            {"libicudata771.so", "libicudata.so.77.1"},
            {"libicui18n771.so", "libicui18n.so.77.1"},
            {"libicuio771.so", "libicuio.so.77.1"},
            {"libicutest771.so", "libicutest.so.77.1"},
            {"libicutu771.so", "libicutu.so.77.1"},
            {"libicuuc771.so", "libicuuc.so.77.1"},
            {"libicudata771.so", "libicudata.so.77"},
            {"libicui18n771.so", "libicui18n.so.77"},
            {"libicuio771.so", "libicuio.so.77"},
            {"libicutest771.so", "libicutest.so.77"},
            {"libicutu771.so", "libicutu.so.77"},
            {"libicuuc771.so", "libicuuc.so.77"},
            {"libzstd1.so", "libzstd.so.1"},
            {"libiconv.so", "libiconv.so"},
            {"libxxhash0.so", "libxxhash.so.0"}
        };
        
        // Define additional symlinks that point to existing libraries  
        String[][] additionalSymlinks = {
            {"libz1.so", "libz.so.1"},         // Node.js needs libz.so.1
            {"libz131.so", "libz.so.1.3.1"},  // Full version symlink
            {"liblzma581.so", "liblzma.so.5"}, // lzma version symlink
            {"libicudata771.so", "libicudata.so.77"},  // ICU data version symlink
            {"libicui18n771.so", "libicui18n.so.77"},  // ICU i18n version symlink
            {"libicuio771.so", "libicuio.so.77"},      // ICU io version symlink
            {"libicutest771.so", "libicutest.so.77"},  // ICU test version symlink
            {"libicutu771.so", "libicutu.so.77"},      // ICU tu version symlink
            {"libicuuc771.so", "libicuuc.so.77"}       // ICU uc version symlink
        };
        
        // Create symlinks for executables in /usr/bin
        for (String[] exe : executables) {
            String sourcePath = nativeLibDir + "/" + exe[0];
            File sourceFile = new File(sourcePath);
            
            if (sourceFile.exists()) {
                String linkPath = binDir + "/" + exe[1];
                File linkFile = new File(linkPath);
                
                // Remove existing link if present
                if (linkFile.exists()) {
                    linkFile.delete();
                }
                
                // Ensure parent directory exists
                linkFile.getParentFile().mkdirs();
                
                // Create symbolic link
                Os.symlink(sourcePath, linkPath);
                Logger.logInfo(LOG_TAG, "Created executable symlink: " + linkPath + " -> " + sourcePath);
            }
        }
        
        // Create symlinks for libraries in /usr/lib
        for (String[] lib : libraries) {
            String sourcePath = nativeLibDir + "/" + lib[0];
            File sourceFile = new File(sourcePath);
            
            if (sourceFile.exists()) {
                String linkPath = libDir + "/" + lib[1];
                File linkFile = new File(linkPath);
                
                // Remove existing link if present
                if (linkFile.exists()) {
                    linkFile.delete();
                }
                
                // Ensure parent directory exists
                linkFile.getParentFile().mkdirs();
                
                // Create symbolic link
                Os.symlink(sourcePath, linkPath);
                Logger.logInfo(LOG_TAG, "Created library symlink: " + linkPath + " -> " + sourcePath);
            }
        }
        
        // Create additional versioned symlinks within /usr/lib
        for (String[] symlink : additionalSymlinks) {
            String sourcePath = libDir + "/" + symlink[0];  // Point to existing symlink in /usr/lib
            File sourceFile = new File(sourcePath);
            
            if (sourceFile.exists()) {
                String linkPath = libDir + "/" + symlink[1];
                File linkFile = new File(linkPath);
                
                // Remove existing link if present
                if (linkFile.exists()) {
                    linkFile.delete();
                }
                
                // Ensure parent directory exists
                linkFile.getParentFile().mkdirs();
                
                // Create symbolic link
                Os.symlink(sourcePath, linkPath);
                Logger.logInfo(LOG_TAG, "Created versioned library symlink: " + linkPath + " -> " + sourcePath);
            }
        }
        
        // Create shell profile with PATH and LD_LIBRARY_PATH configuration
        String profileFile = TermuxConstants.TERMUX_HOME_DIR_PATH + "/.profile";
        String profileContent = "# Termux shell profile\n" +
            "export HOME=" + TermuxConstants.TERMUX_HOME_DIR_PATH + "\n" +
            "export PREFIX=" + TermuxConstants.TERMUX_PREFIX_DIR_PATH + "\n" +
            "export PATH=" + binDir + ":$PATH\n" +
            "export LD_LIBRARY_PATH=" + nativeLibDir + ":" + libDir + ":$LD_LIBRARY_PATH\n" +
            "\n" +
            "# Native executables and libraries are linked from read-only /data/app location\n" +
            "# Executables in " + binDir + "\n" +
            "# Libraries in " + libDir + "\n" +
            "# Native libraries in " + nativeLibDir + "\n";
            
        try (FileOutputStream outStream = new FileOutputStream(profileFile)) {
            outStream.write(profileContent.getBytes());
        }
        
        // Set readable permissions
        File profile = new File(profileFile);
        Os.chmod(profile.getAbsolutePath(), 0644);
        
        Logger.logInfo(LOG_TAG, "Created .profile with PATH and LD_LIBRARY_PATH configuration");
    }
    

    public static void showBootstrapErrorDialog(Activity activity, Runnable whenDone, String message) {
        Logger.logErrorExtended(LOG_TAG, "Bootstrap Error:\n" + message);

        // Send a notification with the exception so that the user knows why bootstrap setup failed
        sendBootstrapCrashReportNotification(activity, message);

        activity.runOnUiThread(() -> {
            try {
                new AlertDialog.Builder(activity).setTitle(R.string.bootstrap_error_title).setMessage(R.string.bootstrap_error_body)
                    .setNegativeButton(R.string.bootstrap_error_abort, (dialog, which) -> {
                        dialog.dismiss();
                        activity.finish();
                    })
                    .setPositiveButton(R.string.bootstrap_error_try_again, (dialog, which) -> {
                        dialog.dismiss();
                        FileUtils.deleteFile("termux prefix directory", TERMUX_PREFIX_DIR_PATH, true);
                        TermuxInstaller.setupBootstrapIfNeeded(activity, whenDone);
                    }).show();
            } catch (WindowManager.BadTokenException e1) {
                // Activity already dismissed - ignore.
            }
        });
    }

    private static void sendBootstrapCrashReportNotification(Activity activity, String message) {
        final String title = TermuxConstants.TERMUX_APP_NAME + " Bootstrap Error";

        // Add info of all install Termux plugin apps as well since their target sdk or installation
        // on external/portable sd card can affect Termux app files directory access or exec.
        TermuxCrashUtils.sendCrashReportNotification(activity, LOG_TAG,
            title, null, "## " + title + "\n\n" + message + "\n\n" +
                TermuxUtils.getTermuxDebugMarkdownString(activity),
            true, false, TermuxUtils.AppInfoMode.TERMUX_AND_PLUGIN_PACKAGES, true);
    }

    static void setupStorageSymlinks(final Context context) {
        final String LOG_TAG = "termux-storage";
        final String title = TermuxConstants.TERMUX_APP_NAME + " Setup Storage Error";

        Logger.logInfo(LOG_TAG, "Setting up storage symlinks.");

        new Thread() {
            public void run() {
                try {
                    Error error;
                    File storageDir = TermuxConstants.TERMUX_STORAGE_HOME_DIR;

                    error = FileUtils.clearDirectory("~/storage", storageDir.getAbsolutePath());
                    if (error != null) {
                        Logger.logErrorAndShowToast(context, LOG_TAG, error.getMessage());
                        Logger.logErrorExtended(LOG_TAG, "Setup Storage Error\n" + error.toString());
                        TermuxCrashUtils.sendCrashReportNotification(context, LOG_TAG, title, null,
                            "## " + title + "\n\n" + Error.getErrorMarkdownString(error),
                            true, false, TermuxUtils.AppInfoMode.TERMUX_PACKAGE, true);
                        return;
                    }

                    Logger.logInfo(LOG_TAG, "Setting up storage symlinks at ~/storage/shared, ~/storage/downloads, ~/storage/dcim, ~/storage/pictures, ~/storage/music and ~/storage/movies for directories in \"" + Environment.getExternalStorageDirectory().getAbsolutePath() + "\".");

                    // Get primary storage root "/storage/emulated/0" symlink
                    File sharedDir = Environment.getExternalStorageDirectory();
                    Os.symlink(sharedDir.getAbsolutePath(), new File(storageDir, "shared").getAbsolutePath());

                    File documentsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOCUMENTS);
                    Os.symlink(documentsDir.getAbsolutePath(), new File(storageDir, "documents").getAbsolutePath());

                    File downloadsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS);
                    Os.symlink(downloadsDir.getAbsolutePath(), new File(storageDir, "downloads").getAbsolutePath());

                    File dcimDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DCIM);
                    Os.symlink(dcimDir.getAbsolutePath(), new File(storageDir, "dcim").getAbsolutePath());

                    File picturesDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES);
                    Os.symlink(picturesDir.getAbsolutePath(), new File(storageDir, "pictures").getAbsolutePath());

                    File musicDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MUSIC);
                    Os.symlink(musicDir.getAbsolutePath(), new File(storageDir, "music").getAbsolutePath());

                    File moviesDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MOVIES);
                    Os.symlink(moviesDir.getAbsolutePath(), new File(storageDir, "movies").getAbsolutePath());

                    File podcastsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PODCASTS);
                    Os.symlink(podcastsDir.getAbsolutePath(), new File(storageDir, "podcasts").getAbsolutePath());

                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
                        File audiobooksDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_AUDIOBOOKS);
                        Os.symlink(audiobooksDir.getAbsolutePath(), new File(storageDir, "audiobooks").getAbsolutePath());
                    }

                    // Dir 0 should ideally be for primary storage
                    // https://cs.android.com/android/platform/superproject/+/android-12.0.0_r32:frameworks/base/core/java/android/app/ContextImpl.java;l=818
                    // https://cs.android.com/android/platform/superproject/+/android-12.0.0_r32:frameworks/base/core/java/android/os/Environment.java;l=219
                    // https://cs.android.com/android/platform/superproject/+/android-12.0.0_r32:frameworks/base/core/java/android/os/Environment.java;l=181
                    // https://cs.android.com/android/platform/superproject/+/android-12.0.0_r32:frameworks/base/services/core/java/com/android/server/StorageManagerService.java;l=3796
                    // https://cs.android.com/android/platform/superproject/+/android-7.0.0_r36:frameworks/base/services/core/java/com/android/server/MountService.java;l=3053

                    // Create "Android/data/com.termux" symlinks
                    File[] dirs = context.getExternalFilesDirs(null);
                    if (dirs != null && dirs.length > 0) {
                        for (int i = 0; i < dirs.length; i++) {
                            File dir = dirs[i];
                            if (dir == null) continue;
                            String symlinkName = "external-" + i;
                            Logger.logInfo(LOG_TAG, "Setting up storage symlinks at ~/storage/" + symlinkName + " for \"" + dir.getAbsolutePath() + "\".");
                            Os.symlink(dir.getAbsolutePath(), new File(storageDir, symlinkName).getAbsolutePath());
                        }
                    }

                    // Create "Android/media/com.termux" symlinks
                    dirs = context.getExternalMediaDirs();
                    if (dirs != null && dirs.length > 0) {
                        for (int i = 0; i < dirs.length; i++) {
                            File dir = dirs[i];
                            if (dir == null) continue;
                            String symlinkName = "media-" + i;
                            Logger.logInfo(LOG_TAG, "Setting up storage symlinks at ~/storage/" + symlinkName + " for \"" + dir.getAbsolutePath() + "\".");
                            Os.symlink(dir.getAbsolutePath(), new File(storageDir, symlinkName).getAbsolutePath());
                        }
                    }

                    Logger.logInfo(LOG_TAG, "Storage symlinks created successfully.");
                } catch (Exception e) {
                    Logger.logErrorAndShowToast(context, LOG_TAG, e.getMessage());
                    Logger.logStackTraceWithMessage(LOG_TAG, "Setup Storage Error: Error setting up link", e);
                    TermuxCrashUtils.sendCrashReportNotification(context, LOG_TAG, title, null,
                        "## " + title + "\n\n" + Logger.getStackTracesMarkdownString(null, Logger.getStackTracesStringArray(e)),
                        true, false, TermuxUtils.AppInfoMode.TERMUX_PACKAGE, true);
                }
            }
        }.start();
    }

    private static Error ensureDirectoryExists(File directory) {
        return FileUtils.createDirectoryFile(directory.getAbsolutePath());
    }


}
