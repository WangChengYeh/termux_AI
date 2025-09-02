package com.termux.app;

import android.app.Activity;
import android.app.AlertDialog;
import android.app.ProgressDialog;
import android.content.Context;
import android.content.res.AssetManager;
import android.os.Build;
import android.os.Environment;
import android.system.Os;
import android.view.WindowManager;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
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
            bootstrapErrorMessage = activity.getString(R.string.bootstrap_error_not_primary_user_message);
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
                bootstrapErrorMessage += "\n\n" + activity.getString(R.string.bootstrap_error_installed_on_portable_sd);
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
        
        // Extract assets (scripts and supporting files) to runtime directory
        extractAssets(activity);
        
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
        
        // Define executables that go to /usr/bin - multiple commands can point to same source
        String[][] executables = {
            {"libcodex.so", "codex"},
            {"libcodex-exec.so", "codex-exec"},
            {"libapt.so", "apt"},
            {"libdpkg.so", "dpkg"},
            {"libdpkg-buildapi.so", "dpkg-buildapi"},
            {"libdpkg-buildtree.so", "dpkg-buildtree"},
            {"libdpkg-deb.so", "dpkg-deb"},
            {"libdpkg-divert.so", "dpkg-divert"},
            {"libdpkg-fsys-usrunmess.so", "dpkg-fsys-usrunmess"},
            {"libdpkg-query.so", "dpkg-query"},
            {"libdpkg-realpath.so", "dpkg-realpath"},
            {"libdpkg-split.so", "dpkg-split"},
            {"libdpkg-trigger.so", "dpkg-trigger"},
            {"libstart-stop-daemon.so", "start-stop-daemon"},
            {"libupdate-alternatives.so", "update-alternatives"},
            {"libnode.so", "node"},
            {"libenv.so", "env"},
            {"libenv.so", "printenv"},
            {"libbash.so", "bash"},
            {"libvim.so", "vim"},
            // Coreutils 9.7-3 - multicall binary with 100+ utilities
            {"libcoreutils.so", "["},
            {"libcoreutils.so", "b2sum"},
            {"libcoreutils.so", "base32"},
            {"libcoreutils.so", "base64"},
            {"libcoreutils.so", "basename"},
            {"libcoreutils.so", "basenc"},
            {"libcoreutils.so", "cat"},
            {"libcoreutils.so", "chcon"},
            {"libcoreutils.so", "chgrp"},
            {"libcoreutils.so", "chmod"},
            {"libcoreutils.so", "chown"},
            {"libcoreutils.so", "chroot"},
            {"libcoreutils.so", "cksum"},
            {"libcoreutils.so", "comm"},
            {"libcoreutils.so", "cp"},
            {"libcoreutils.so", "csplit"},
            {"libcoreutils.so", "cut"},
            {"libcoreutils.so", "date"},
            {"libcoreutils.so", "dd"},
            {"libcoreutils.so", "dir"},
            {"libcoreutils.so", "dircolors"},
            {"libcoreutils.so", "dirname"},
            {"libcoreutils.so", "du"},
            {"libcoreutils.so", "echo"},
            // {"libcoreutils.so", "env"},  // Skip - conflicts with libenv.so
            // {"libcoreutils.so", "printenv"},  // Skip - conflicts with libenv.so
            {"libcoreutils.so", "expand"},
            {"libcoreutils.so", "expr"},
            {"libcoreutils.so", "factor"},
            {"libcoreutils.so", "false"},
            {"libcoreutils.so", "fmt"},
            {"libcoreutils.so", "fold"},
            {"libcoreutils.so", "groups"},
            {"libcoreutils.so", "head"},
            {"libcoreutils.so", "id"},
            {"libcoreutils.so", "install"},
            {"libcoreutils.so", "join"},
            {"libcoreutils.so", "kill"},
            {"libcoreutils.so", "link"},
            {"libcoreutils.so", "ln"},
            {"libcoreutils.so", "logname"},
            {"libcoreutils.so", "ls"},
            {"libcoreutils.so", "md5sum"},
            {"libcoreutils.so", "mkdir"},
            {"libcoreutils.so", "mkfifo"},
            {"libcoreutils.so", "mknod"},
            {"libcoreutils.so", "mktemp"},
            {"libcoreutils.so", "mv"},
            {"libcoreutils.so", "nice"},
            {"libcoreutils.so", "nl"},
            {"libcoreutils.so", "nohup"},
            {"libcoreutils.so", "nproc"},
            {"libcoreutils.so", "numfmt"},
            {"libcoreutils.so", "od"},
            {"libcoreutils.so", "paste"},
            {"libcoreutils.so", "pathchk"},
            {"libcoreutils.so", "pr"},
            {"libcoreutils.so", "printf"},
            {"libcoreutils.so", "ptx"},
            {"libcoreutils.so", "pwd"},
            {"libcoreutils.so", "readlink"},
            {"libcoreutils.so", "realpath"},
            {"libcoreutils.so", "rm"},
            {"libcoreutils.so", "rmdir"},
            {"libcoreutils.so", "runcon"},
            {"libcoreutils.so", "seq"},
            {"libcoreutils.so", "sha1sum"},
            {"libcoreutils.so", "sha224sum"},
            {"libcoreutils.so", "sha256sum"},
            {"libcoreutils.so", "sha384sum"},
            {"libcoreutils.so", "sha512sum"},
            {"libcoreutils.so", "shred"},
            {"libcoreutils.so", "shuf"},
            {"libcoreutils.so", "sleep"},
            {"libcoreutils.so", "sort"},
            {"libcoreutils.so", "split"},
            {"libcoreutils.so", "stat"},
            {"libcoreutils.so", "stdbuf"},
            {"libcoreutils.so", "stty"},
            {"libcoreutils.so", "sum"},
            {"libcoreutils.so", "sync"},
            {"libcoreutils.so", "tac"},
            {"libcoreutils.so", "tail"},
            {"libcoreutils.so", "tee"},
            {"libcoreutils.so", "test"},
            {"libcoreutils.so", "timeout"},
            {"libcoreutils.so", "touch"},
            {"libcoreutils.so", "tr"},
            {"libcoreutils.so", "true"},
            {"libcoreutils.so", "truncate"},
            {"libcoreutils.so", "tsort"},
            {"libcoreutils.so", "tty"},
            {"libcoreutils.so", "uname"},
            {"libcoreutils.so", "unexpand"},
            {"libcoreutils.so", "uniq"},
            {"libcoreutils.so", "unlink"},
            {"libcoreutils.so", "vdir"},
            {"libcoreutils.so", "wc"},
            {"libcoreutils.so", "whoami"},
            {"libcoreutils.so", "yes"}
        };
        
        // Define base libraries that create primary symlinks in /usr/lib
        String[] baseLibraries = {
            "libandroid-glob.so",
            "libapt-private.so", 
            "libapt-pkg.so",
            "libc++_shared.so",
            "libz1.so",
            "libcares.so",
            "libbz210.so",
            "libsqlite3.so",
            "libcrypto3.so",
            "libssl3.so",
            "liblzma5.so",
            "libicudata771.so",
            "libicui18n771.so",
            "libicuio771.so",
            "libicutest771.so",
            "libicutu771.so",
            "libicuuc771.so",
            "libzstd1.so",
            "libiconv.so",
            "libxxhash0.so",
            "libgcrypt.so",
            "libgpg-error.so",
            "libmd.so",
            "libandroid-support.so",
            "libreadline83.so",
            "libhistory83.so",
            "libncurses6.so",
            "libcoreutils.so",
            "libandroid-selinux.so",
            "libgmp.so",
            "libgmpxx.so",
            "libpcre2-8.so",
            "libpcre2-16.so",
            "libpcre2-32.so",
            "libpcre2-posix.so"
        };
        
        // Define version postfix symlinks that point to base libraries in /usr/lib
        String[][] versionSymlinks = {
            // zlib versions - unified to libz1.so (removed libz131.so, libzlib.so)
            {"libz1.so", "libz.so"},
            {"libz1.so", "libz.so.1"},
            {"libz1.so", "libz.so.1.3.1"},
            {"libz1.so", "libz131.so"},
            {"libz1.so", "libzlib.so"},
            // bz2 versions  
            {"libbz210.so", "libbz2.so"},
            {"libbz210.so", "libbz2.so.1.0"},
            // sqlite versions
            {"libsqlite3.so", "libsqlite3.so.0"},
            // openssl versions
            {"libcrypto3.so", "libcrypto.so.3"},
            {"libssl3.so", "libssl.so.3"},
            // lzma versions - unified to liblzma5.so (removed liblzma581.so)
            {"liblzma5.so", "liblzma.so"},
            {"liblzma5.so", "liblzma.so.5"},
            {"liblzma5.so", "liblzma.so.5.8.1"},
            {"liblzma5.so", "liblzma581.so"},
            // ICU versions  
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
            // zstd versions
            {"libzstd1.so", "libzstd.so.1"},
            // xxhash versions
            {"libxxhash0.so", "libxxhash.so.0"},
            // readline versions
            {"libreadline83.so", "libreadline.so"},
            {"libreadline83.so", "libreadline.so.8"},
            // history versions
            {"libhistory83.so", "libhistory.so"},
            {"libhistory83.so", "libhistory.so.8"},
            // ncurses versions - unified to libncurses6.so (removed libncursesw6.so)
            {"libncurses6.so", "libncurses.so"},
            {"libncurses6.so", "libncurses.so.6"},
            {"libncurses6.so", "libncursesw.so"},
            {"libncurses6.so", "libncursesw.so.6"},
            {"libncurses6.so", "libncursesw6.so"},
            // GMP versions - GNU Multiple Precision Arithmetic Library
            {"libgmp.so", "libgmp.so.10"},
            {"libgmpxx.so", "libgmpxx.so.4"}
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
        
        // Create base library symlinks in /usr/lib pointing to /data/app/.../lib/arm64/
        for (String libName : baseLibraries) {
            String sourcePath = nativeLibDir + "/" + libName;
            File sourceFile = new File(sourcePath);
            
            if (sourceFile.exists()) {
                String linkPath = libDir + "/" + libName;
                File linkFile = new File(linkPath);
                
                // Remove existing link if present
                if (linkFile.exists()) {
                    linkFile.delete();
                }
                
                // Ensure parent directory exists
                linkFile.getParentFile().mkdirs();
                
                // Create symbolic link from /usr/lib to /data/app/.../lib/arm64/
                Os.symlink(sourcePath, linkPath);
                Logger.logInfo(LOG_TAG, "Created base library symlink: " + linkPath + " -> " + sourcePath);
            }
        }
        
        // Create version postfix symlinks within /usr/lib pointing to base libraries
        for (String[] versionLink : versionSymlinks) {
            String sourceLibPath = libDir + "/" + versionLink[0];  // Point to base library in /usr/lib
            File sourceFile = new File(sourceLibPath);
            
            if (sourceFile.exists()) {
                String linkPath = libDir + "/" + versionLink[1];
                File linkFile = new File(linkPath);
                
                // Remove existing link if present
                if (linkFile.exists()) {
                    linkFile.delete();
                }
                
                // Ensure parent directory exists
                linkFile.getParentFile().mkdirs();
                
                // Create symbolic link within /usr/lib
                Os.symlink(sourceLibPath, linkPath);
                Logger.logInfo(LOG_TAG, "Created version symlink: " + linkPath + " -> " + sourceLibPath);
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
    
    /**
     * Extract assets (scripts and supporting files) to runtime directory
     */
    private static void extractAssets(Context context) throws Exception {
        AssetManager assets = context.getAssets();
        String termuxDir = TermuxConstants.TERMUX_PREFIX_DIR_PATH;
        
        Logger.logInfo(LOG_TAG, "Extracting assets to: " + termuxDir);
        
        // Extract usr/bin scripts
        extractAssetDirectory(assets, "termux/usr/bin", termuxDir + "/bin");
        
        // Extract usr/lib supporting files (including node_modules)
        extractAssetDirectory(assets, "termux/usr/lib", termuxDir + "/lib");
        
        Logger.logInfo(LOG_TAG, "Assets extracted successfully");
    }
    
    /**
     * Recursively extract asset directory to target directory
     */
    private static void extractAssetDirectory(AssetManager assets, String assetPath, String targetDir) throws Exception {
        String[] files;
        try {
            files = assets.list(assetPath);
        } catch (IOException e) {
            Logger.logInfo(LOG_TAG, "No assets found at: " + assetPath);
            return;
        }
        
        if (files == null || files.length == 0) {
            // This is a file, not a directory - extract it
            extractAssetFile(assets, assetPath, targetDir);
            return;
        }
        
        // This is a directory - create it and recurse
        File targetDirFile = new File(targetDir);
        if (!targetDirFile.exists()) {
            targetDirFile.mkdirs();
        }
        
        for (String file : files) {
            String childAssetPath = assetPath + "/" + file;
            String childTargetPath = targetDir + "/" + file;
            extractAssetDirectory(assets, childAssetPath, childTargetPath);
        }
    }
    
    /**
     * Extract a single asset file to target path
     */
    private static void extractAssetFile(AssetManager assets, String assetPath, String targetPath) throws Exception {
        File targetFile = new File(targetPath);
        
        // Skip if file already exists and is not empty
        if (targetFile.exists() && targetFile.length() > 0) {
            return;
        }
        
        // Create parent directory if needed
        File parentDir = targetFile.getParentFile();
        if (parentDir != null && !parentDir.exists()) {
            parentDir.mkdirs();
        }
        
        try (InputStream inputStream = assets.open(assetPath);
             FileOutputStream outputStream = new FileOutputStream(targetFile)) {
            
            byte[] buffer = new byte[8192];
            int bytesRead;
            while ((bytesRead = inputStream.read(buffer)) != -1) {
                outputStream.write(buffer, 0, bytesRead);
            }
        }
        
        // Set executable permissions for files in bin directory
        if (targetPath.contains("/bin/")) {
            Os.chmod(targetFile.getAbsolutePath(), 0755);
        } else {
            Os.chmod(targetFile.getAbsolutePath(), 0644);
        }
        
        Logger.logInfo(LOG_TAG, "Extracted asset: " + assetPath + " -> " + targetPath);
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
