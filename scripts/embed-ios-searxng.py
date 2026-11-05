#!/usr/bin/env python3
# Created by Sébastien DAGUIN
"""Package signed Python iOS frameworks and SearXNG resources before app signing."""

import os
from pathlib import Path
import plistlib
import shutil
import subprocess


def run(*command):
    subprocess.run([str(value) for value in command], check=True)


def main():
    project = Path(os.environ["SRCROOT"])
    runtime = project / "build/SearXNG-iOS"
    platform = os.environ["PLATFORM_NAME"]
    if os.environ["ARCHS"].split() != ["arm64"]:
        raise RuntimeError("The embedded iOS SearXNG runtime supports arm64 device and Simulator builds")
    packages = runtime / platform / "app_packages"
    if not packages.exists():
        raise RuntimeError("Prepare iOS SearXNG with setup_ios_runtime.py; see README.md")
    app = Path(os.environ["TARGET_BUILD_DIR"]) / os.environ["WRAPPER_NAME"]
    frameworks = app / "Frameworks"
    frameworks.mkdir(parents=True, exist_ok=True)
    identity = os.environ.get("EXPANDED_CODE_SIGN_IDENTITY") or "-"
    slice_name = "ios-arm64" if platform == "iphoneos" else "ios-arm64_x86_64-simulator"
    support = runtime / "Python.xcframework"
    target = support / slice_name
    for name in ("python", "SearXNG"):
        path = app / name
        if path.exists():
            shutil.rmtree(path)
    shutil.copytree(support / "lib", app / "python/lib", ignore=shutil.ignore_patterns("__pycache__", "libpython*.dylib"))
    shutil.copytree(target / "lib-arm64", app / "python/lib", dirs_exist_ok=True,
                    ignore=shutil.ignore_patterns("__pycache__", "libpython*.dylib"))
    shutil.copytree(packages, app / "SearXNG/app_packages", ignore=shutil.ignore_patterns("__pycache__", "*.pyc"))
    shutil.copy2(project / "scripts/ios_searxng.py", app / "SearXNG/ios_searxng.py")
    python_framework = frameworks / "Python.framework"
    if python_framework.exists():
        shutil.rmtree(python_framework)
    shutil.copytree(target / "Python.framework", python_framework)
    shutil.rmtree(python_framework / "Headers", ignore_errors=True)
    shutil.rmtree(python_framework / "Modules", ignore_errors=True)
    run("codesign", "--force", "--sign", identity, "--timestamp=none", python_framework)

    def framework(binary, name):
        folder = frameworks / f"{name}.framework"
        folder.mkdir(exist_ok=True)
        executable = folder / name
        shutil.copy2(binary, executable)
        run("install_name_tool", "-id", f"@rpath/{name}.framework/{name}", executable)
        info = {"CFBundleExecutable": name, "CFBundleName": name,
                "CFBundleIdentifier": "com.sebastiendaguin.NoctisAi.python." + name.replace("_", "-"),
                "CFBundlePackageType": "FMWK", "CFBundleVersion": "1", "CFBundleShortVersionString": "1.0",
                "MinimumOSVersion": "17.6", "CFBundleSupportedPlatforms": ["iPhoneOS" if platform == "iphoneos" else "iPhoneSimulator"]}
        data = plistlib.dumps(info).replace(b"?>\n", "?>\n<!-- Created by Sébastien DAGUIN -->\n".encode(), 1)
        (folder / "Info.plist").write_bytes(data)
        return folder, executable

    curl_library = next((runtime / platform / "curl").glob("libcurl-impersonate.[0-9]*.[0-9]*.[0-9]*.dylib"))
    curl_framework, _ = framework(curl_library, "CurlImpersonate")
    notices = app / "SearXNG/licenses/CurlImpersonate"
    notices.mkdir(parents=True, exist_ok=True)
    for notice in (runtime / platform / "curl").glob("LICENSE*"):
        shutil.copy2(notice, notices / notice.name)
    run("codesign", "--force", "--sign", identity, "--timestamp=none", curl_framework)
    for base in (app / "python/lib/python3.13/lib-dynload", app / "SearXNG/app_packages"):
        for binary in base.rglob("*.so"):
            relative = binary.relative_to(base)
            name = ".".join((*relative.parts[:-1], relative.name.split(".")[0]))
            folder, executable = framework(binary, name)
            marker = binary.with_suffix(".fwork")
            marker.write_text(str(executable.relative_to(app)))
            (folder / f"{name}.origin").write_text(str(marker.relative_to(app)))
            privacy = binary.parent / (relative.name.split(".")[0] + ".xcprivacy")
            if privacy.exists():
                shutil.copy2(privacy, folder / "PrivacyInfo.xcprivacy")
            run("codesign", "--force", "--sign", identity, "--timestamp=none", folder)
            binary.unlink()


if __name__ == "__main__":
    main()
