# Set up the native runner yourself

Run these commands on the Mac as the account that runs GitHub Actions. They install
tools and large simulator images; they do not sign, publish or contact a family server.
Use a checkout of this PR while it is under review, and the default branch after merge.

## 1. Prepare the selected Xcode and command-line tools

Xcode must already be selected, licensed and through its first-launch setup. These
commands inspect it and download a compatible iOS Simulator runtime for the selected
Xcode. The installed runtime's exact version/build is pinned in step 3.

```bash
xcodebuild -version
xcodebuild -downloadPlatform iOS -architectureVariant arm64
brew install openjdk@17 node@22 gh
export JAVA_HOME="$(brew --prefix openjdk@17)/libexec/openjdk.jdk/Contents/Home"
export PATH="$(brew --prefix node@22)/bin:$JAVA_HOME/bin:$PATH"
```

## 2. Install this repository's pinned Flutter SDK

From the repository root:

```bash
qualification_flutter_version=$(sed -n 's/^  flutter: *\([0-9][0-9.]*\) *$/\1/p' app/pubspec.yaml)
test -n "$qualification_flutter_version"
qualification_flutter_dir="$HOME/.cache/wuselwall-flutter/$qualification_flutter_version"
if [ ! -d "$qualification_flutter_dir" ]; then
  mkdir -p "$(dirname "$qualification_flutter_dir")"
  git clone --depth 1 --branch "$qualification_flutter_version" \
    https://github.com/flutter/flutter.git "$qualification_flutter_dir"
fi
export PATH="$qualification_flutter_dir/bin:$PATH"
flutter --version
npm ci --include=dev
```

Node 22 or later and Python 3 must be available. The Actions workflow installs its
own pinned Flutter, Node and JDK; these exports are for this local setup session.

## 3. Pin the installed simulator runtime

List installed runtimes compatible with both configured test devices and print the
export commands for each exact version, build and identifier. The newest runtime can
support only a special device model, so availability alone is insufficient. Copy the
three commands for one compatible runtime into this shell. If several
runtimes are installed, choose the one intended for qualification rather than changing
or deleting the others.

```bash
xcrun simctl list runtimes --json | python3 -c '
import json, os, shlex, sys
devices = {
    os.environ.get("QUALIFICATION_IOS_PHONE_TYPE", "com.apple.CoreSimulator.SimDeviceType.iPhone-16"),
    os.environ.get("QUALIFICATION_IOS_TABLET_TYPE", "com.apple.CoreSimulator.SimDeviceType.iPad-Pro-11-inch-M4-8GB"),
}
for runtime in json.load(sys.stdin)["runtimes"]:
    if runtime.get("isAvailable") and runtime["identifier"].startswith("com.apple.CoreSimulator.SimRuntime.iOS-"):
        supported = {device["identifier"] for device in runtime.get("supportedDeviceTypes", [])}
        if not devices.issubset(supported):
            print("# " + runtime["name"] + ": does not list support for both configured test devices")
            continue
        print("# " + runtime["name"])
        for key, value in [("QUALIFICATION_IOS_VERSION", runtime["version"]),
                           ("QUALIFICATION_IOS_BUILD", runtime["buildversion"]),
                           ("QUALIFICATION_IOS_RUNTIME", runtime["identifier"])]:
            print("export " + key + "=" + shlex.quote(value))
'
```

## 4. Review and apply the dedicated installation

The dry run makes no downloads or filesystem changes. The default requires at least
100 GiB free. Review the Android SDK licenses before using the explicit acceptance
flag on the apply command.

```bash
export QUALIFICATION_TOOLS_ROOT="$HOME/.cache/wuselwall-qualification"
bash qualification/native/provision.sh --dry-run
QUALIFICATION_ACCEPT_ANDROID_LICENSES=true bash qualification/native/provision.sh --apply
```

The script installs only the pinned packages in `toolchain.json` and three dedicated
CI AVDs. It records the SDK, AVD and simulator settings in the private
`$QUALIFICATION_TOOLS_ROOT/environment.env`; it does not change shell profiles.

## 5. Connect the installation to Actions

Authenticate `gh` for the repository if necessary, then set the tools-directory variable.
The workflow's safe loader restores the remaining settings from the private file.
Do not commit this machine-specific path or the generated environment file.

```bash
gh variable set QUALIFICATION_TOOLS_ROOT --repo wuselwall/wuselwall-app \
  --body "$QUALIFICATION_TOOLS_ROOT"
```

Run the manual native preflight workflow after merge, then collect a native **capture**
run before reviewing baselines. The existing iOS workflow also offers a
`diagnostics_only=true` manual mode during PR review; that mode skips signing and
publishing. A capture cannot qualify a release.

Diagnostics load the saved tool settings when the tools-directory variable is configured.
An invalid saved configuration still fails the job, and the read-only probes and their
artifact run so the failure remains inspectable.

The release gate separately requires a GitHub environment named `release-promotion`,
at least one required reviewer, and administrator bypass disabled. The reviewer accepts
baseline changes and the physical-device checklist for the exact candidate commit.
