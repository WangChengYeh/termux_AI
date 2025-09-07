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

import java.io.BufferedReader;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;

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
            {"codex.so", "codex"},
            {"codex-exec.so", "codex-exec"},
            {"apt.so", "apt"},
            {"apt-mark.so", "apt-mark"},
            {"apt-cache.so", "apt-cache"},
            {"apt-config.so", "apt-config"},
            {"apt-get.so", "apt-get"},
            {"dpkg.so", "dpkg"},
            {"dpkg-buildapi.so", "dpkg-buildapi"},
            {"dpkg-buildtree.so", "dpkg-buildtree"},
            {"dpkg-deb.so", "dpkg-deb"},
            {"dpkg-divert.so", "dpkg-divert"},
            {"dpkg-fsys-usrunmess.so", "dpkg-fsys-usrunmess"},
            {"dpkg-query.so", "dpkg-query"},
            {"dpkg-realpath.so", "dpkg-realpath"},
            {"dpkg-split.so", "dpkg-split"},
            {"dpkg-trigger.so", "dpkg-trigger"},
            {"start-stop-daemon.so", "start-stop-daemon"},
            {"update-alternatives.so", "update-alternatives"},
            {"node.so", "node"},
            {"npm.so", "npm"},
            {"npx.so", "npx"},
            {"corepack.so", "corepack"},
            {"git.so", "git"},
            {"git-daemon.so", "git-daemon"},
            {"git-http-backend.so", "git-http-backend"},
            {"git-http-fetch.so", "git-http-fetch"},
            {"git-http-push.so", "git-http-push"},
            {"git-imap-send.so", "git-imap-send"},
            {"git-remote-http.so", "git-remote-http"},
            {"git-sh-i18n--envsubst.so", "git-sh-i18n--envsubst"},
            {"git-receive-pack.so", "git-receive-pack"},
            {"gh.so", "gh"},
            {"curl.so", "curl"},
            {"which.so", "which"},
            {"ssh-keyscan.so", "ssh-keyscan"},
            {"sshd.so", "sshd"},
            {"sftp.so", "sftp"},
            {"ssh-agent.so", "ssh-agent"},
            {"ssh.so", "ssh"},
            {"ssh-add.so", "ssh-add"},
            {"ssh-keygen.so", "ssh-keygen"},
            {"scp.so", "scp"},
            {"env.so", "env"},
            {"env.so", "printenv"},
            {"bash.so", "bash"},
            {"vim.so", "vim"},
            {"vim.so", "rview"},
            // Coreutils 9.7-3 - multicall binary with 100+ utilities
            {"coreutils.so", "["},
            {"coreutils.so", "b2sum"},
            {"coreutils.so", "base32"},
            {"coreutils.so", "base64"},
            {"coreutils.so", "basename"},
            {"coreutils.so", "basenc"},
            {"coreutils.so", "cat"},
            {"coreutils.so", "chcon"},
            {"coreutils.so", "chgrp"},
            {"coreutils.so", "chmod"},
            {"coreutils.so", "chown"},
            {"coreutils.so", "chroot"},
            {"coreutils.so", "cksum"},
            {"coreutils.so", "comm"},
            {"coreutils.so", "cp"},
            {"coreutils.so", "csplit"},
            {"coreutils.so", "cut"},
            {"coreutils.so", "date"},
            {"coreutils.so", "dd"},
            {"coreutils.so", "dir"},
            {"coreutils.so", "dircolors"},
            {"coreutils.so", "dirname"},
            {"coreutils.so", "du"},
            {"coreutils.so", "echo"},
            // {"coreutils.so", "env"},  // Skip - conflicts with libenv.so
            // {"coreutils.so", "printenv"},  // Skip - conflicts with libenv.so
            {"coreutils.so", "expand"},
            {"coreutils.so", "expr"},
            {"coreutils.so", "factor"},
            {"coreutils.so", "false"},
            {"coreutils.so", "fmt"},
            {"coreutils.so", "fold"},
            {"coreutils.so", "groups"},
            {"coreutils.so", "head"},
            {"coreutils.so", "id"},
            {"coreutils.so", "install"},
            {"coreutils.so", "join"},
            {"coreutils.so", "kill"},
            {"coreutils.so", "link"},
            {"coreutils.so", "ln"},
            {"coreutils.so", "logname"},
            {"coreutils.so", "ls"},
            {"coreutils.so", "md5sum"},
            {"coreutils.so", "mkdir"},
            {"coreutils.so", "mkfifo"},
            {"coreutils.so", "mknod"},
            {"coreutils.so", "mktemp"},
            {"coreutils.so", "mv"},
            {"coreutils.so", "nice"},
            {"coreutils.so", "nl"},
            {"coreutils.so", "nohup"},
            {"coreutils.so", "nproc"},
            {"coreutils.so", "numfmt"},
            {"coreutils.so", "od"},
            {"coreutils.so", "paste"},
            {"coreutils.so", "pathchk"},
            {"coreutils.so", "pr"},
            {"coreutils.so", "printf"},
            {"coreutils.so", "ptx"},
            {"coreutils.so", "pwd"},
            {"coreutils.so", "readlink"},
            {"coreutils.so", "realpath"},
            {"coreutils.so", "rm"},
            {"coreutils.so", "rmdir"},
            {"coreutils.so", "runcon"},
            {"coreutils.so", "seq"},
            {"coreutils.so", "sha1sum"},
            {"coreutils.so", "sha224sum"},
            {"coreutils.so", "sha256sum"},
            {"coreutils.so", "sha384sum"},
            {"coreutils.so", "sha512sum"},
            {"coreutils.so", "shred"},
            {"coreutils.so", "shuf"},
            {"coreutils.so", "sleep"},
            {"coreutils.so", "sort"},
            {"coreutils.so", "split"},
            {"coreutils.so", "stat"},
            {"coreutils.so", "stdbuf"},
            {"coreutils.so", "stty"},
            {"coreutils.so", "sum"},
            {"coreutils.so", "sync"},
            {"coreutils.so", "tac"},
            {"coreutils.so", "tail"},
            {"coreutils.so", "tee"},
            {"coreutils.so", "test"},
            {"coreutils.so", "timeout"},
            {"coreutils.so", "touch"},
            {"coreutils.so", "tr"},
            {"coreutils.so", "true"},
            {"coreutils.so", "truncate"},
            {"coreutils.so", "tsort"},
            {"coreutils.so", "tty"},
            {"coreutils.so", "uname"},
            {"coreutils.so", "unexpand"},
            {"coreutils.so", "uniq"},
            {"coreutils.so", "unlink"},
            {"coreutils.so", "vdir"},
            {"coreutils.so", "wc"},
            {"coreutils.so", "whoami"},
            {"coreutils.so", "yes"},
            // Kerberos executables
            {"kproplog.so", "kproplog"},
            {"krb5kdc.so", "krb5kdc"},
            {"gss-server.so", "gss-server"},
            {"ktutil.so", "ktutil"},
            {"uuclient.so", "uuclient"},
            {"sserver.so", "sserver"},
            {"kprop.so", "kprop"},
            {"kadmin.local.so", "kadmin.local"},
            {"kinit.so", "kinit"},
            {"kdb5_util.so", "kdb5_util"},
            {"kpropd.so", "kpropd"},
            {"sim_server.so", "sim_server"},
            {"kpasswd.so", "kpasswd"},
            {"kdestroy.so", "kdestroy"},
            {"kvno.so", "kvno"},
            {"kadmind.so", "kadmind"},
            {"gss-client.so", "gss-client"},
            {"uuserver.so", "uuserver"},
            {"ksu.so", "ksu"},
            {"sclient.so", "sclient"},
            {"kswitch.so", "kswitch"},
            {"kadmin.so", "kadmin"},
            {"sim_client.so", "sim_client"},
            {"klist.so", "klist"},
            // DNS tools
            {"drill.so", "drill"},
            // DNS utilities from BIND 9.20.12
            {"dig.so", "dig"},
            {"nslookup.so", "nslookup"},
            {"host.so", "host"},
            {"delv.so", "delv"},
            {"nsupdate.so", "nsupdate"},
            {"arpaname.so", "arpaname"},
            {"mdig.so", "mdig"},
            {"named.so", "named"},
            {"rndc.so", "rndc"},
            {"rndc-confgen.so", "rndc-confgen"},
            {"ddns-confgen.so", "ddns-confgen"},
            {"tsig-keygen.so", "tsig-keygen"},
            {"named-checkconf.so", "named-checkconf"},
            {"named-checkzone.so", "named-checkzone"},
            {"named-compilezone.so", "named-compilezone"},
            {"named-journalprint.so", "named-journalprint"},
            {"named-rrchecker.so", "named-rrchecker"},
            {"dnssec-keygen.so", "dnssec-keygen"},
            {"dnssec-signzone.so", "dnssec-signzone"},
            {"dnssec-verify.so", "dnssec-verify"},
            {"dnssec-dsfromkey.so", "dnssec-dsfromkey"},
            {"dnssec-keyfromlabel.so", "dnssec-keyfromlabel"},
            {"dnssec-revoke.so", "dnssec-revoke"},
            {"dnssec-settime.so", "dnssec-settime"},
            {"dnssec-importkey.so", "dnssec-importkey"},
            {"dnssec-cds.so", "dnssec-cds"},
            {"dnssec-ksr.so", "dnssec-ksr"},
            {"nsec3hash.so", "nsec3hash"},
            // Text pager utilities
            {"less.so", "less"},
            {"lessecho.so", "lessecho"},
            {"lesskey.so", "lesskey"},
            // Web terminal
            {"ttyd.so", "ttyd"},
            // OpenCL utilities
            {"libcllayerinfo.so", "cllayerinfo"},
            // WebP image format utilities
            {"libwebpmux.so", "webpmux"},
            {"libwebpinfo.so", "webpinfo"},
            {"libimg2webp.so", "img2webp"},
            {"libgif2webp.so", "gif2webp"},
            {"libdwebp.so", "dwebp"},
            {"libcwebp.so", "cwebp"},
            // AV1 video decoder
            {"libdav1d.so", "dav1d"},
            // SVT-AV1 video encoder
            {"libSvtAv1EncApp.so", "SvtAv1EncApp"},
            // Rubber Band audio time-stretching and pitch-shifting tools
            {"librubberband.so", "rubberband"},
            {"librubberband-r3.so", "rubberband-r3"},
            // ZeroMQ messaging library tools
            {"libcurve_keygen.so", "curve_keygen"},
            // Android Codex CLI
            {"codex.so", "codex"},
            {"codex-exec.so", "codex-exec"},
            // Compression utilities
            {"libbrotli.so", "brotli"},
            {"bzip2recover.so", "bzip2recover"},
            {"lzmainfo.so", "lzmainfo"},
            // Terminal utilities
            {"tset.so", "tset"},
            // Cryptographic utilities
            {"dumpsexp.so", "dumpsexp"},
            {"mpicalc.so", "mpicalc"},
            {"hmac256.so", "hmac256"},
            {"libgpg-error.so", "gpg-error"},
            {"yat2m.so", "yat2m"},
            // Compression utilities
            {"zstd.so", "zstd"},
            // AI CLI tools
            {"gemini.so", "gemini"},
            {"claude.so", "claude"},
            // FFmpeg multimedia tools
            {"ffmpeg.so", "ffmpeg"},
            {"ffprobe.so", "ffprobe"},
            // Font rendering tools
            {"freetype-config.so", "freetype-config"},
            // GLib tools
            {"gtester.so", "gtester"},
            {"gsettings.so", "gsettings"},
            {"glib-compile-schemas.so", "glib-compile-schemas"},
            {"gobject-query.so", "gobject-query"},
            {"gi-decompile-typelib.so", "gi-decompile-typelib"},
            {"gio-querymodules.so", "gio-querymodules"},
            {"gapplication.so", "gapplication"},
            {"glib-compile-resources.so", "glib-compile-resources"},
            {"gresource.so", "gresource"},
            {"gdbus.so", "gdbus"},
            {"gi-compile-repository.so", "gi-compile-repository"},
            {"gi-inspect-typelib.so", "gi-inspect-typelib"},
            {"gio.so", "gio"}
        };
        
        // Define base libraries that create primary symlinks in /usr/lib
        String[] baseLibraries = {
            "libandroid-glob.so",
            "libapt-private.so", 
            "libapt-pkg.so",
            "libapt-mark.so",
            "libapt-cache.so", 
            "libapt-config.so",
            "libapt-get.so",
            "libc++_shared.so",
            "libz.so",
            "libcares.so",
            "libbz2.so",
            "libsqlite3.so",
            "libcrypto.so",
            "libssl.so",
            "libssh2.so",
            "liblzma.so",
            "libicudata.so",
            "libicui18n.so",
            "libicuio.so",
            "libicutest.so",
            "libicutu.so",
            "libicuuc.so",
            "libzstd.so",
            "libiconv.so",
            "libcharset.so",
            "libcurl.so",
            "libnghttp2.so",
            "libxxhash0.so",
            "libgcrypt.so",
            "libgpg-error.so",
            "libmd.so",
            "libandroid-support.so",
            "libreadline83.so",
            "libreadline8.so",
            "libhistory8.so",
            "libhistory83.so",
            "libncurses6.so",
            "coreutils.so",
            "libandroid-selinux.so",
            "libgmp.so",
            "libgmpxx.so",
            "libpcre2-8.so",
            "libpcre2-16.so",
            "libpcre2-32.so",
            "libpcre2-posix.so",
            "libldns.so",
            "libverto.so",
            "libgssrpc.so",
            "libgssapi_krb5.so",
            "libkdb5.so",
            "libkrb5.so",
            "libkadm5clnt_mit.so",
            "libkrb5support.so",
            "libkadm5srv_mit.so",
            "libk5crypto.so",
            "libkrad.so",
            "libcom_err.so",
            "libjson-c.so",
            "libxml2-16.so",
            "libandroid-execinfo.so",
            // BIND 9.20.12 libraries
            "libisccc-9.20.12.so",
            "libisc-9.20.12.so", 
            "libns-9.20.12.so",
            "libdns-9.20.12.so",
            "libisccfg-9.20.12.so",
            // Kerberos plugins (renamed to libxxx.so)
            "libfilter-aaaa.so",
            "libfilter-a.so",
            "libdb2.so",
            "libk5tls.so",
            "libotp.so",
            "libpkinit.so",
            "libspake.so",
            "libtest.so",
            "libtermux-exec-ld-preload.so",
            "libtermux-exec_nos_c_tre.so",
            "libtermux-exec-linker-ld-preload.so",
            "libtermux-exec-direct-ld-preload.so",
            // Web terminal support
            "libwebsockets.so",
            "libwebsockets-evlib_uv.so",
            "libgit-receive-pack.so",
            // Additional missing libraries
            "libnghttp3.so",
            "libuv.so",
            "libxml2-16.so",
            "libkrad0.so",
            "libisccfg.so",
            // FFmpeg libraries
            "libavutil.so",
            "libavfilter.so",
            "libpostproc.so",
            "libswscale.so",
            "libswresample.so",
            "libavdevice.so",
            "libavcodec.so",
            "libavformat.so",
            // FFmpeg dependencies
            "libass.so",
            "libfreetype.so",
            "libiconv.so",
            "libcharset.so",
            "libandroid-glob.so",
            // GLib libraries
            "libglib-2.0.so",
            "libgio-2.0.so",
            "libgmodule-2.0.so",
            "libgobject-2.0.so",
            "libgthread-2.0.so",
            "libgirepository-2.0.so",
            // Graphite2 library for harfbuzz
            "libgraphite2.so",
            "libgnutls.so",
            "libgnutlsxx.so",
            "libvpx.so",
            "libmp3lame.so",
            "libopus.so",
            "libvorbis.so",
            "libvorbisenc.so", 
            "libvorbisfile.so",
            "libx264.so",
            "libx265.so",
            "libxvidcore.so",
            "libsoxr.so",
            "libsoxr-lsr.so",
            "libfribidi.so",
            "libfontconfig.so",
            "libharfbuzz.so",
            "libharfbuzz-cairo.so",
            "libharfbuzz-gobject.so",
            "libharfbuzz-subset.so",
            "libpng16.so",
            "libidn2.so",
            "libunistring.so",
            "libnettle.so",
            "libhogweed.so",
            "libogg.so",
            "libandroid-posix-semaphore.so",
            "libexpat.so",
            "libavutil.so",
            "libavcodec.so",
            "libavformat.so",
            "libavfilter.so",
            "libavdevice.so",
            // FFmpeg versioned libraries
            "libavutil59.so",
            "libavcodec61.so",
            "libavformat61.so",
            "libavfilter10.so",
            "libavdevice61.so",
            "libpostproc58.so",
            "libswresample5.so",
            "libswscale8.so",
            // ZeroMQ library for FFmpeg
            "libzmq.so",
            // Rubber Band audio stretching library for FFmpeg
            "librubberband.so",
            // libzimg scaling, colorspace conversion, and dithering library
            "libzimg.so",
            // OpenCL ICD Loader
            "libOpenCL.so",
            // Game Music Emu library
            "libgme.so",
            // OpenMPT library for tracker music
            "libopenmpt.so",
            // Blu-ray disc playback library
            "libbluray.so",
            // Secure Reliable Transport (SRT) Protocol
            "libsrt.so",
            // Tiny C SSH library
            "libssh.so",
            // WebP image format libraries
            "libwebp.so",
            "libwebpmux.so",
            "libwebpdecoder.so", 
            "libwebpdemux.so",
            "libsharpyuv.so",
            // AV1 video decoder library
            "libdav1d.so",
            // OpenCORE AMR audio codec libraries
            "libopencore-amrwb.so",
            "libopencore-amrnb.so",
            // AV1 video encoder library
            "libaom.so",
            // Rav1e AV1 encoder library (Rust-based)
            "librav1e.so",
            // SVT-AV1 encoder library (Scalable Video Technology)
            "libSvtAv1Enc.so",
            // Theora video codec libraries
            "libtheoraenc.so",
            "libtheora.so",
            "libtheoradec.so",
            // VisualOn AMR-WB encoder library
            "libvo-amrwbenc.so",
            // Sodium cryptographic library (for libzmq)
            "libsodium.so",
            // MPG123 MPEG audio decoder library suite
            "libmpg123.so",
            "libsyn123.so",
            "libout123.so",
            // UDF filesystem library for Blu-ray support
            "libudfread.so",
            // FLAC (Free Lossless Audio Codec) libraries
            "libFLAC.so",
            "libFLAC++.so",
            // Rubber Band audio time-stretching and pitch-shifting libraries
            "librubberband.so",
            "librubberband-jni.so"
        };
        
        // Define version postfix symlinks that point to base libraries in /usr/lib
        String[][] versionSymlinks = {
            // zlib versions - unified to libz.so (removed libz1.so, libz131.so, libzlib.so)
            {"libz.so", "libz.so.1"},
            {"libz.so", "libz.so.1.3.1"},
            {"libz.so", "libz131.so"},
            {"libz.so", "libzlib.so"},
            // bz2 versions  
            {"libbz2.so", "libbz2.so.1.0"},
            // sqlite versions
            {"libsqlite3.so", "libsqlite3.so.0"},
            // openssl versions
            {"libcrypto.so", "libcrypto.so.3"},
            {"libssl.so", "libssl.so.3"},
            // lzma versions - unified to liblzma5.so (removed liblzma581.so)
            {"liblzma.so", "liblzma.so.5"},
            {"liblzma.so", "liblzma.so.5.8.1"},
            // ICU versions  
            {"libicudata.so", "libicudata.so.77.1"},
            {"libicui18n.so", "libicui18n.so.77.1"},
            {"libicuio.so", "libicuio.so.77.1"},
            {"libicutest.so", "libicutest.so.77.1"},
            {"libicutu.so", "libicutu.so.77.1"},
            {"libicuuc.so", "libicuuc.so.77.1"},
            {"libicudata.so", "libicudata.so.77"},
            {"libicui18n.so", "libicui18n.so.77"},
            {"libicuio.so", "libicuio.so.77"},
            {"libicutest.so", "libicutest.so.77"},
            {"libicutu.so", "libicutu.so.77"},
            {"libicuuc.so", "libicuuc.so.77"},
            // zstd versions
            {"libzstd.so", "libzstd.so.1"},
            // xxhash versions
            {"libxxhash0.so", "libxxhash.so.0"},
            // readline versions
            {"libreadline8.so", "libreadline.so.8"},
            {"libreadline8.so", "libreadline.so.8.3"},
            {"libreadline83.so", "libreadline.so"},
            // history versions
            {"libhistory8.so", "libhistory.so.8"},
            {"libhistory8.so", "libhistory.so.8.3"},
            {"libhistory83.so", "libhistory.so"},
            // libxml2 versions
            {"libxml2-16.so", "libxml2.so"},
            {"libxml2-16.so", "libxml2.so.16"},
            {"libxml2-16.so", "libxml2.so.16.0.5"},
            // execinfo versions
            {"libandroid-execinfo.so", "libexecinfo.so"},
            // ncurses versions - unified to libncurses6.so (removed libncursesw6.so)
            {"libncurses6.so", "libncurses.so"},
            {"libncurses6.so", "libncurses.so.6"},
            {"libncurses6.so", "libncursesw.so"},
            {"libncurses6.so", "libncursesw.so.6"},
            {"libncurses6.so", "libncursesw6.so"},
            // GMP versions - GNU Multiple Precision Arithmetic Library
            {"libgmp.so", "libgmp.so.10"},
            {"libgmpxx.so", "libgmpxx.so.4"},
            // Kerberos/GSSAPI versions (updated for krb5 v1.22.1-1)
            {"libgssapi_krb5.so", "libgssapi_krb5.so.2"},
            {"libkrb5.so", "libkrb5.so.3"},
            {"libkdb5.so", "libkdb5.so.10"},
            {"libkrb5support.so", "libkrb5support.so.0"},
            {"libkadm5clnt_mit.so", "libkadm5clnt_mit.so.12"},
            {"libkadm5srv_mit.so", "libkadm5srv_mit.so.12"},
            {"libgssrpc.so", "libgssrpc.so.4"},
            {"libk5crypto.so", "libk5crypto.so.3"},
            {"libkrad.so", "libkrad.so.0"},
            {"libcom_err.so", "libcom_err.so.3"},
            {"libverto.so", "libverto.so.0"},
            {"libcom_err3.so", "libcom_err.so"},
            // expat versions
            {"libexpat.so", "libexpat.so.1"},
            {"libexpat.so", "libexpat.so.1.10.2"},
            {"libverto0.so", "libverto.so.0"},
            {"libverto0.so", "libverto.so"},
            {"libgssrpc4.so", "libgssrpc.so.4"},
            {"libgssrpc4.so", "libgssrpc.so"},
            {"libkdb59.so", "libkdb5.so.9"},
            {"libkdb59.so", "libkdb5.so"},
            {"libkadm5clnt_mit11.so", "libkadm5clnt_mit.so.11"},
            {"libkadm5clnt_mit11.so", "libkadm5clnt_mit.so"},
            {"libkadm5srv_mit11.so", "libkadm5srv_mit.so.11"},
            {"libkadm5srv_mit11.so", "libkadm5srv_mit.so"},
            {"libkrad0.so", "libkrad.so.0"},
            {"libkrad0.so", "libkrad.so"},
            // Kerberos plugins - symlinks to original names (without lib prefix)
            {"libfilter-aaaa.so", "filter-aaaa.so"},
            {"libfilter-a.so", "filter-a.so"},
            {"libdb2.so", "db2.so"},
            {"libk5tls.so", "k5tls.so"},
            {"libotp.so", "otp.so"},
            {"libpkinit.so", "pkinit.so"},
            {"libspake.so", "spake.so"},
            {"libtest.so", "test.so"},
            // libvpx versions
            {"libvpx.so", "libvpx.so.6"},
            {"libvpx.so", "libvpx.so.6.1.0"},
            {"libvpx.so", "libvpx.so.11"},
            // librav1e versions
            {"librav1e.so", "librav1e.so.0"},
            {"librav1e.so", "librav1e.so.0.7.1"},
            // libvo-amrwbenc versions
            {"libvo-amrwbenc.so", "libvo-amrwbenc.so.0"},
            {"libvo-amrwbenc.so", "libvo-amrwbenc.so.0.0.4"},
            // libx264 versions
            {"libx264.so", "libx264.so.155"},
            {"libx264.so", "libx264.so.164"},
            // libxvidcore versions
            {"libxvidcore.so", "libxvidcore.so.4"},
            {"libxvidcore.so", "libxvidcore.so.4.3"},
            // libsoxr versions
            {"libsoxr.so", "libsoxr.so.0"},
            // libpng versions
            {"libpng16.so", "libpng.so"},
            // libnettle versions
            {"libnettle.so", "libnettle.so.7"},
            {"libnettle.so", "libnettle.so.8"},
            {"libnettle.so", "libnettle.so.8.11"},
            // libhogweed versions
            {"libhogweed.so", "libhogweed.so.5"},
            {"libhogweed.so", "libhogweed.so.6"},
            {"libhogweed.so", "libhogweed.so.6.11"},
            // libogg versions
            {"libogg.so", "libogg.so.0"},
            // GLib library versions
            {"libglib-2.0.so", "libglib-2.0.so.0"},
            {"libgio-2.0.so", "libgio-2.0.so.0"},
            {"libgmodule-2.0.so", "libgmodule-2.0.so.0"},
            {"libgobject-2.0.so", "libgobject-2.0.so.0"},
            {"libgthread-2.0.so", "libgthread-2.0.so.0"},
            {"libgirepository-2.0.so", "libgirepository-2.0.so.0"},
            // FFmpeg 7.1.1 versioned libraries - create symlinks from base to versioned names
            {"libavutil59.so", "libavutil.so.59"},
            {"libavcodec61.so", "libavcodec.so.61"},
            {"libavformat61.so", "libavformat.so.61"},
            {"libavfilter10.so", "libavfilter.so.10"},
            {"libavdevice61.so", "libavdevice.so.61"},
            {"libpostproc58.so", "libpostproc.so.58"},
            {"libswresample5.so", "libswresample.so.5"},
            {"libswscale8.so", "libswscale.so.8"}
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
            "# Native libraries in " + nativeLibDir + "\n" +
            "\n" +
            "# Source additional environment configuration if available\n" +
            "if [ -f /data/local/tmp/android_sourceme ]; then\n" +
            "    source /data/local/tmp/android_sourceme\n" +
            "fi\n";
            
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
        
        // Extract usr/etc configuration files (CA certificates, DNS config, etc.)
        extractAssetDirectory(assets, "termux/usr/etc", termuxDir + "/etc");
        
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
        // Check if this is a symlink indicator file
        if (assetPath.endsWith(".symlink")) {
            // Remove .symlink extension from target path
            String actualTargetPath = targetPath.substring(0, targetPath.length() - 8);
            
            // Read symlink target from the indicator file
            try (InputStream inputStream = assets.open(assetPath);
                 BufferedReader reader = new BufferedReader(new InputStreamReader(inputStream))) {
                
                String line = reader.readLine();
                if (line != null && line.startsWith("SYMLINK:")) {
                    String symlinkTarget = line.substring(8);
                    
                    // Create the symlink
                    File targetFile = new File(actualTargetPath);
                    
                    // Remove existing file/link if present
                    if (targetFile.exists()) {
                        targetFile.delete();
                    }
                    
                    // Create parent directory if needed
                    File parentDir = targetFile.getParentFile();
                    if (parentDir != null && !parentDir.exists()) {
                        parentDir.mkdirs();
                    }
                    
                    // Create symbolic link
                    Os.symlink(symlinkTarget, actualTargetPath);
                    Logger.logInfo(LOG_TAG, "Created symlink: " + actualTargetPath + " -> " + symlinkTarget);
                    return;
                }
            }
        }
        
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
