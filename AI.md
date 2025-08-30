# Termux AI: AI CLI (Codex) + MCP (Python) + SDK Upgrade (security)

This document defines the target: Termux AI — AI CLI (Codex) + MCP (Python) + SDK Upgrade (security). It focuses on delivering an AI-first Termux experience: a fork of `termux/termux-app` upgraded to the latest Android SDK/AGP with a preloaded AI package (Codex) available on first run. The MCP (Model Context Protocol) is provided as an optional AI extension and requires Python as a runtime dependency.

Important: This fork supports only aarch64 (ARM64, `arm64-v8a`). Other ABIs are not supported and will not receive binaries or bootstraps.

## Goals
- Target: Termux AI — AI CLI (Codex) + MCP (Python) + SDK Upgrade (security).
- Deliver an AI-ready fork that:
  - Targets the latest stable Android SDK and modern AGP/Gradle.
  - Keeps Termux core functionality intact (scoped storage, permissions, UX).
  - Preloads the core AI package: Codex CLI (`codex`) by default.
  - Offers MCP (`mcp`) as an optional extension; installs offline if enabled.
  - Uses Python strictly as the MCP extension runtime dependency.
  - Complies with Android 10+ execution constraints (executables in app-private storage).

## Scope
- Repo: Fork of `https://github.com/termux/termux-app` (app module only; not changing `termux-packages` upstream except for our custom bootstrap build).
- Android minSdk: 33, update `compileSdk`/`targetSdk` to latest (see below).
- Architectures: ARM aarch64 (`arm64-v8a`) only. All other ABIs (ARMv7, x86, x86_64) are explicitly unsupported.
- Distribution: GitHub Releases (APK + bootstrap artifacts). Google Play is out-of-scope due to existing Termux policy constraints.

## Fork Strategy
1. Fork via GitHub UI (or CLI) to org/user of choice.
   - CLI example (requires `gh`):
     ```bash
     gh repo fork termux/termux-app --clone --remote
     cd termux-app
     git checkout -b feat/codex-ai-preload
     ```
2. Keep upstream in sync:
   ```bash
   git remote add upstream https://github.com/termux/termux-app.git
   git fetch upstream
   git rebase upstream/master   # or merge if preferred
   ```
3. CI will build aarch64-only APKs and attach to releases; Codex/MCP aarch64 assets will be built by a companion workflow (see “AI Package & Extension”).

## Android Toolchain Upgrade
Target latest stable at time of work (proposed: Android 14/15 APIs):
- Gradle Wrapper: 8.5–8.7
- Android Gradle Plugin (AGP): 8.4–8.6 (pair with wrapper)
- Java toolchain: 17
- `compileSdk`: 35 (Android 14+)
- `targetSdk`: 35
- `minSdk`: 33

Concrete changes:
- `gradle/wrapper/gradle-wrapper.properties`
  - Update distribution URL to Gradle 8.5+.
- `build.gradle` (project) → migrate to `settings.gradle` plugins DSL if not already; bump AGP to 8.x.
- `app/build.gradle` (or `build.gradle.kts`):
  ```groovy
  android {
      namespace "com.termux" // if not already present (AGP 8 requires)
      compileSdk 35

      defaultConfig {
          applicationId "com.termux"
          minSdk 33
          targetSdk 35
          versionCode <keep/bump>
          versionName "<keep/bump>"
      }

      compileOptions {
          sourceCompatibility JavaVersion.VERSION_17
          targetCompatibility JavaVersion.VERSION_17
      }

      packagingOptions {
          resources.excludes += ["META-INF/LICENSE*", "META-INF/DEPENDENCIES"]
      }
  }

  dependencies {
      // Migrate to latest AndroidX/Material versions
      implementation "androidx.core:core-ktx:<latest>"
      implementation "androidx.appcompat:appcompat:<latest>"
      implementation "com.google.android.material:material:<latest>"
      // Update any legacy support libs -> AndroidX
  }
  ```
- `gradle.properties`:
  ```
  org.gradle.jvmargs=-Xmx3g -Dfile.encoding=UTF-8
  android.useAndroidX=true
  android.enableJetifier=true
  ```

Required code/manifest updates for minSdk 33 and targetSdk ≥ 31:
- Add `android:exported="true|false"` to every `Activity`, `Service`, and `Receiver` with an intent-filter.
- `PendingIntent` must specify mutability: use `FLAG_IMMUTABLE` where possible, `FLAG_MUTABLE` where required.
- Android 13+ notifications: declare `POST_NOTIFICATIONS` and request runtime permission for API 33+:
  ```xml
  <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
  ```
- Foreground services: ensure proper types and `ServiceInfo.FOREGROUND_SERVICE_TYPE_*` if applicable.
- Storage: remove deprecated `requestLegacyExternalStorage`; rely on SAF and Termux’s internal storage model.

Validation:
- `./gradlew :app:lint :app:assembleDebug` must pass.
- Runtime checks on API 33 and 35 devices/emulators.

## Storage & File Access
- Termux home remains inside app-internal storage.
- For shared storage, keep `termux-setup-storage` flow, using SAF/Tree URIs. Avoid `MANAGE_EXTERNAL_STORAGE` to keep policy-friendly.
- Validate content resolver paths and `DocumentFile` usage as needed for targetSdk 30+ behavior.

## AI Package & Extension
We want first-run to provide an AI-capable terminal with Codex as the core package and MCP as an optional extension.
- Core AI package: Codex CLI (`codex`) — always installed where supported (aarch64 initially).
- Optional AI extension: MCP (`mcp`) — installs offline on first run if the user enables the extension (settings prompt), otherwise skipped.

Python is included only to power the MCP extension; Codex works without Python.

Two viable approaches (choose based on APK size and hosting constraints):

1) Embedded Bootstrap (APK Assets) — Selected
- Due to Android 10+ execution restrictions (executables must reside in app package/private storage), we will embed the minimal bootstrap plus required executables in APK `assets/` and extract on first run.
- Pros: Fully offline, compliant with exec policy, deterministic. Cons: Larger APKs; mitigated with ABI splits.

2) Custom Bootstrap Download (Fallback/Optional)
- Keep support for downloading a larger bootstrap from our release mirrors if we decide to trim APK size later.

### Building AI Bootstrap/Assets (aarch64-only)
- Use `termux-packages` to build bootstraps with an expanded package list.
- Steps:
  ```bash
  git clone https://github.com/termux/termux-packages.git
  cd termux-packages
  # Option A: Quick include via env var (aarch64 only)
  export TERMUX_BOOTSTRAP_PACKAGES="bash coreutils ca-certificates python"
  ./scripts/run-docker.sh ./build-package.sh -a aarch64 bootstrap
  ```
- Alternatively, modify `scripts/build-bootstraps.sh` or the package list used by bootstrap build to always include `python`.
- Output: `bootstrap-aarch64.zip`.

Optional: Offline wheels for AI extension dependencies (aarch64 only)
- Gather pure-python or manylinux wheels for selected libs (e.g., `requests`, `numpy` if feasible for Termux).
- Place wheels under a `wheels/` directory inside bootstrap, plus a post-install script:
  ```bash
  pip install --no-index --find-links=/data/data/com.termux/files/usr/share/wheels -r /data/data/com.termux/files/usr/share/wheels/requirements.txt
  ```
- Ensure license compliance and architecture compatibility.

### Optional MCP Extension (Python-backed)
Goal: When enabled, `mcp` is usable immediately after first run without internet or manual setup.

- Base packages for extension: include `python`, `openssl`, `libffi` so SSL modules work.
- Preload wheels (pure-Python preferred) for MCP:
  - Primary: `mcp[cli]==<pin>` (Python package providing the `mcp` command)
  - This will pull dependencies like `typer`, `rich`, `prompt_toolkit`, `anyio`, `httpx`, `websockets`, `pydantic` (versions resolved at download time).
- During bootstrap build (offline bundle creation):
  ```bash
  mkdir -p out/wheels/mcp-cli
  # From a build host with internet
  python3 -m pip download -d out/wheels/mcp-cli 'mcp[cli]==<pin>'
  # Optionally, add exact versions via constraints for deterministic installs
  ```
- Place downloaded wheels into the bootstrap at:
  - `usr/share/wheels/mcp-cli/` (inside the bootstrap archive)
- Post-install script (runs on device, no internet):
  ```bash
  #!/data/data/com.termux/files/usr/bin/sh
  set -e
  WHEELS_DIR="$PREFIX/share/wheels/mcp-cli"
  if [ -d "$WHEELS_DIR" ]; then
    # Ensure pip exists and SSL works
    command -v pip >/dev/null 2>&1 || python -m ensurepip --upgrade
    pip install --no-index --find-links="$WHEELS_DIR" 'mcp[cli]==<pin>'
  fi
  # Provide a lightweight wrapper if entrypoint not exposed
  if ! command -v mcp >/dev/null 2>&1; then
    cat > "$PREFIX/bin/mcp" <<'EOF'
#!/data/data/com.termux/files/usr/bin/sh
exec python -m mcp "$@"
EOF
    chmod +x "$PREFIX/bin/mcp"
  fi
  ```
- Verification (first run smoke test):
  - If extension enabled: `codex exec /mcp` shows CLI usage without network.
  - `python --version` is informational only.
  - Document MCP config under `$HOME/.config/mcp/*` when integrating with Codex or other tools.

### Codex CLI (Core AI package, aarch64-only)
- Artifact: `android-codex-cli-binaries-0.25.0-aarch64.tar.gz`
  - Source: https://github.com/WangChengYeh/codex_android/releases/download/v0.25.0/android-codex-cli-binaries-0.25.0-aarch64.tar.gz
  - Arch: aarch64 only. Not available on arm, x86, or x86_64.
- Placement strategy (APK assets):
  - Place the tarball and a SHA256 file under `app/src/main/assets/extras/aarch64/codex/`.
  - On first run, extract from assets into `$PREFIX/opt/codex` and symlink into `$PREFIX/bin`.
- Example bootstrap integration (post-install script excerpt):
  ```bash
  #!/data/data/com.termux/files/usr/bin/sh
  set -euo pipefail
  ARCH=$(getprop ro.product.cpu.abi || echo aarch64)
  if [ "$ARCH" = "arm64-v8a" ] || [ "$ARCH" = "aarch64" ]; then
    ASSETS_DIR="/data/data/com.termux/files/usr/share/.preload-assets"
    CODex_TARBALL="$ASSETS_DIR/extras/aarch64/codex/android-codex-cli-binaries-0.25.0-aarch64.tar.gz"
    CODex_SHA256="$ASSETS_DIR/extras/aarch64/codex/android-codex-cli-binaries-0.25.0-aarch64.tar.gz.sha256"
    sha256sum -c "$CODex_SHA256"
    tmpdir=$(mktemp -d)
    tar -C "$tmpdir" -xzf "$CODex_TARBALL"
    mkdir -p "$PREFIX/opt/codex" "$PREFIX/bin"
    cp -a "$tmpdir"/* "$PREFIX/opt/codex/"
    for b in codex codexd codex-cli; do
      if [ -f "$PREFIX/opt/codex/bin/$b" ]; then
        ln -sf "$PREFIX/opt/codex/bin/$b" "$PREFIX/bin/$b"
      fi
    done
    rm -rf "$tmpdir"
  fi
  ```
  - At build time, ensure these assets are marked no-compress.
  - If we later choose to not embed, we can fall back to downloading and verifying via app logic.

### App Changes for AI Bootstrap (aarch64-only)
- In termux-app source, locate bootstrap download logic (e.g., `BootstrapInstaller`/`TermuxInstaller`).
- Replace upstream mirror URLs with our release URLs; keep a fallback to upstream in case of failure.
- Verify checksum validation and TLS requirements.
- Show progress UI and robust error handling for first-run bootstrap.
- ABI gating: Only surface and install Codex/MCP on aarch64 devices using `Build.SUPPORTED_ABIS`. Non-aarch64 devices must show a clear unsupported-architecture message and exit the installer.

## Android 10+ Exec Policy Compliance
- Executables must reside in the APK or app-private storage; executing from external/shared storage is blocked by the OS sandbox.
- Strategy:
  - Embed minimal bootstrap + AI assets: Codex (aarch64) and MCP wheels (for optional extension) under `app/src/main/assets`.
  - On first launch, copy assets into `$PREFIX` (app-internal: `/data/data/com.termux/files/usr`) and set executable bits.
  - Never place binaries into shared storage.

Gradle configuration (aarch64-only):
- Enable ABI split to ship only aarch64 payloads:
  ```groovy
  android {
    splits {
      abi {
        enable true
        reset()
        include 'arm64-v8a' // aarch64 only
        universalApk false
      }
    }
  }
  ```
- Avoid compressing archives for faster extraction and proper permissions:
  ```groovy
  android {
    aaptOptions { noCompress 'tar', 'gz', 'zip' }
    // For AGP 8+: packaging { resources { noCompress += ['tar','gz','zip'] } }
  }
  ```

Installer (app) logic outline (aarch64-only):
- Prefer assets when present; fall back to network mirrors if not.
- Respect user choice for the MCP extension (opt-in setting default off).
- Pseudocode:
  ```kotlin
  val isArm64 = Build.SUPPORTED_ABIS.contains("arm64-v8a")
  if (!isArm64) {
    // aarch64-only: fail fast with a clear message
    showIncompatibleArchMessage()
    return
  }
  // Core bootstrap (aarch64)
  copyAssetDirToPrefix("bootstrap/arm64-v8a", prefix)
  // Core AI package: Codex
  copyAssetDirToPrefix("extras/arm64-v8a/codex", prefixSharePreload)
  // Optional MCP extension
  if (settings.enableMcp) copyAssetDirToPrefix("extras/arm64-v8a/mcp", prefixSharePreload)
  runPostInstallScripts()
  ```

Permissions/ownership:
- Ensure extracted files are owned by app UID and have `0755` for executables and `0644` for data.
- Validate SELinux contexts are inherited correctly (regular file copy to app-internal dir is fine).

## CI/CD (aarch64-only)
- GitHub Actions matrix for `app`:
  - Build: `./gradlew clean assembleRelease lint`
  - Artifacts: upload `app-release.apk` per build.
- GitHub Actions: aarch64-only
  - Build core APK with Codex assets for `arm64-v8a` and optional MCP assets for `arm64-v8a`.
  - Use Docker on Ubuntu runners to build aarch64 bootstrap including MCP runtime (Python + wheels).
  - Attach `bootstrap-aarch64.zip` and AI extras to a release and publish a JSON index the app can consume.
- Optional: Sign release APKs using GitHub OIDC + secure signing service or self-hosted runner with secrets.

### Automated Package Flow (add → preload → rebuild → release → install)
- Trigger: adding or updating a package to be preloaded (e.g., Codex/MCP deps or new tools).
- Preload manifest: update aarch64-only preload list and versions
  - File: `app/src/main/assets/preload/index-aarch64.json` (logical manifest; generated by CI)
  - Include: package name, version, checksum, asset path under `assets/extras/aarch64/`.
- Build assets (aarch64):
  - Bootstrap: rebuild with required base packages (`python`, etc.).
  - Extras: package the new/updated binaries or wheels into `extras/aarch64/<pkg>/` with `.sha256` files.
  - Outputs: `bootstrap-aarch64.zip`, `extras-<pkg>-aarch64.tar.gz`, checksums.
- Update app assets: CI syncs built artifacts into `app/src/main/assets` and regenerates the preload index.
- Bump version: automatically bump `versionCode` and suffix `versionName` (e.g., `+preload.YYYYMMDD`).
- Build & verify: `./gradlew clean assembleRelease lint` and run minimal instrumentation smoke tests.
- Release: publish GitHub Release with APK + bootstrap/extras, attach the preload manifest for auditing.
- Install flow (device, aarch64, minSdk 33):
  - On first launch, Termux AI reads the preload index, verifies checksums, copies assets to `$PREFIX`, and runs post-install scripts.
  - If user enabled MCP, install wheels offline; always install Codex.
  - Show success and command hints (`codex --version`, `mcp --help`).

Notes
- aarch64-only: CI and app enforce `arm64-v8a` exclusively.
- Determinism: all artifacts include SHA256; app verifies before extraction.
- Rollback: release retains previous assets; users can sideload prior APK if necessary.

## Testing
- Unit: Lint + small unit tests for utilities.
- Instrumented: Smoke test launching `TermuxActivity`, permission flows, notification permission on API 33+.
- E2E manual (aarch64 devices/emulators only): verify:
  - Codex: `codex --version` works.
  - MCP extension (if enabled): `mcp --help` works without network.

## Risks & Mitigations
- APK size growth from AI assets: use ABI splits, prune extras, ship MCP as optional to reduce default payload, consider optional network fetch for heavyweight components.
- License obligations: audit Python & wheels; include LICENSE files in `assets/NOTICE` and release notes.
- ABI compatibility: ensure MCP runtime (Python) and Codex are built/tested for aarch64; show clear message and block install on unsupported ABIs without attempting fallback.
- Scoped storage regressions: test `termux-setup-storage` thoroughly on 30+.
- Upstream divergence: rebase regularly; keep changes minimal and well isolated (URL + SDK updates).

## Deliverables
- GitHub fork with branch `feat/codex-ai-preload`.
- Upgraded Gradle/AGP config and manifest fixes.
- App code changes to embed/copy AI assets from APK and optional network fallback.
- Settings toggle for enabling the MCP extension.
- CI workflows for APK and AI assets/bootstrap artifacts.
- A release with aarch64-only APK and `bootstrap-aarch64.zip`/AI extras.

## Rollout Plan
1. Create fork and branch.
2. Upgrade build system to AGP 8.x, SDK 35; fix build.
3. Implement notification/runtime permission flow for 33+; add `exported` flags, `PendingIntent` fixes.
4. Build and publish custom bootstraps with `python`.
5. Wire app to use embedded Codex assets and optional MCP assets, with index/URLs for network fallback.
6. Add CI; produce signed APKs.
7. Test across API matrix on aarch64 devices/emulators only.

## Unsupported Architectures
- Non-aarch64 devices (ARMv7, x86, x86_64) are not supported.
- The app will not attempt to download or install alternative bootstraps/binaries for unsupported ABIs.
- Users on unsupported devices should install upstream Termux without the AI enhancements.
8. Tag v0.1.0 and release.

## Local Dev Commands (reference)
```bash
# Clone fork and create branch
gh repo fork termux/termux-app --clone --remote
cd termux-app
git checkout -b feat/ai-runtime-preload

# Update Gradle wrapper (example to 8.6)
./gradlew wrapper --gradle-version 8.6 --distribution-type all

# Build APK
'tools/doctor' || true
./gradlew clean :app:assembleDebug :app:lint

# Run unit tests (if present)
./gradlew test

# Build AI bootstraps (in termux-packages)
export TERMUX_BOOTSTRAP_PACKAGES="bash coreutils ca-certificates python"
./scripts/run-docker.sh ./build-package.sh -a aarch64 bootstrap
```

## Open Questions
- Which Python subset and which pip packages should be preloaded by default?
- Acceptable first-run download size target?
- Should we provide a settings toggle to opt-out of preloading and use upstream bootstrap?
- Do we want to maintain our own mirror CDN or rely on GitHub Releases bandwidth?

## Timeline (estimate)
- Week 1: Fork + SDK/AGP upgrade + build green.
- Week 2: Bootstrap build with `python`, publish artifacts, app URL wiring.
- Week 3: CI hardening, testing on devices, first release.

---
Maintainers can iterate on this doc as constraints or goals evolve. PRs against this fork should reference the section they affect.
