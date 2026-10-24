#!/usr/bin/env python3
"""Build both candidates from a captured source tree; never attest pre-existing binaries."""
from pathlib import Path
import argparse
import datetime
import hashlib
import json
import os
import plistlib
import shutil
import subprocess
import tarfile

ROOT = Path(__file__).resolve().parent.parent


def run(*args, cwd=ROOT):
    return subprocess.check_output(args, cwd=cwd, text=True, stderr=subprocess.STDOUT).strip()


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def files_under(path):
    return sorted(f for f in path.rglob("*") if f.is_file() and "__pycache__" not in f.parts)


def tree_sha(files, base):
    digest = hashlib.sha256()
    for path in files:
        digest.update(str(path.relative_to(base)).encode() + b"\0" + sha(path).encode() + b"\n")
    return digest.hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build", action="store_true", required=True,
                        help="Required: capture sources BEFORE compiling both candidates")
    args = parser.parse_args()
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    out = ROOT / ".build/integration-evidence" / ("candidate-" + stamp)
    out.mkdir(parents=True, exist_ok=False)
    sources = sorted([ROOT / "build.sh", ROOT / "README.md"] + [
        f for folder in ["Sources", "Assets", "Tests", "Tools"] for f in files_under(ROOT / folder)
    ])
    hashes = {str(f.relative_to(ROOT)): sha(f) for f in sources}
    archive = out / "source.tar.gz"
    snapshot = out / "source"
    snapshot.mkdir()
    # Preserve both previous app bundles and their prior evidence before any compilation.
    prior = out / "prior-artifacts"
    prior.mkdir()
    for relative in ["Catpacity.app", ".build/Catpacity Verification.app"]:
        existing = ROOT / relative
        if existing.exists():
            shutil.copytree(existing, prior / existing.name)
    for existing in (ROOT / ".build/integration-evidence").iterdir():
        if existing.is_file():
            shutil.copy2(existing, prior / existing.name)
    for relative in [".build/preservation-baseline.json", ".build/product-build.log",
                     ".build/action-tests-development.log", ".build/catworks-tests-development.log"]:
        existing = ROOT / relative
        if existing.exists():
            shutil.copy2(existing, prior / existing.name)
    with tarfile.open(archive, "w:gz") as tar:
        for f in sources:
            relative = str(f.relative_to(ROOT))
            tar.add(f, arcname=relative, recursive=False)
            target = snapshot / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(f, target)
    assert all(sha(snapshot / p) == h == sha(ROOT / p) for p, h in hashes.items()), "Source changed during capture"
    with tarfile.open(archive, "r:gz") as tar:
        assert all(hashlib.sha256(tar.extractfile(p).read()).hexdigest() == h for p, h in hashes.items()), "Archive differs from captured input"
    sdk = Path(os.environ.get("CATPACITY_SDK_PATH") or run("xcrun", "--sdk", "macosx", "--show-sdk-path")).resolve()
    sdk_settings = plistlib.loads((sdk / "SDKSettings.plist").read_bytes())
    compiler = Path(run("xcrun", "--find", "swiftc")).resolve()
    compiler_sha = sha(compiler)
    swift_version = run(str(compiler), "--version")
    env = os.environ.copy()
    env["CATPACITY_SDK_PATH"] = str(sdk)
    module_cache = str(ROOT / ".build/module-cache")
    env["CATPACITY_MODULE_CACHE_PATH"] = module_cache
    # No credential/account environment values are recorded.
    bundles = []
    for mode, relative, destination in [
        ("product", "Catpacity.app", "Catpacity.app"),
        ("verification", ".build/Catpacity Verification.app", "Catpacity Verification.app")
    ]:
        started = datetime.datetime.now(datetime.timezone.utc).isoformat()
        log = out / (mode + "-build.log")
        command = ["/bin/bash", "-x", "build.sh", mode]
        print(f"Building {mode} from captured sources: {snapshot}", flush=True)
        with log.open("w") as stream:
            subprocess.run(command, cwd=snapshot, env=env, stdout=stream, stderr=subprocess.STDOUT, check=True)
        assert sha(compiler) == compiler_sha, "Compiler changed during build"
        assert all(sha(snapshot / p) == h for p, h in hashes.items()), "Captured input changed during build"
        bundle = out / destination
        shutil.copytree(snapshot / relative, bundle)
        signature = run("codesign", "--verify", "--deep", "--strict", str(bundle))
        details = run("codesign", "-d", "--verbose=4", str(bundle))
        info = plistlib.loads((bundle / "Contents/Info.plist").read_bytes())
        executable = bundle / "Contents/MacOS" / info["CFBundleExecutable"]
        archs = run("lipo", "-archs", str(executable)).split()
        assert set(archs) == {"arm64", "x86_64"}, "Missing universal architecture"
        signature_log = out / (mode + "-signature.txt")
        signature_log.write_text(signature + "\n" + details + "\n")
        bundles.append({
            "mode": mode, "path": str(bundle), "bundleID": info["CFBundleIdentifier"],
            "version": info["CFBundleShortVersionString"], "buildStartedAt": started,
            "buildFinishedAt": datetime.datetime.now(datetime.timezone.utc).isoformat(),
            "command": command, "cwd": str(snapshot), "buildLog": str(log), "buildLogSHA256": sha(log),
            "swiftOptions": ["-sdk", str(sdk), "-module-cache-path", module_cache, "-target", "<arch>-apple-macos13.0", "-O"]
                + (["-D", "CATPACITY_VERIFICATION"] if mode == "verification" else []) + ["-parse-as-library"],
            "executableSHA256": sha(executable), "bundleTreeSHA256": tree_sha(files_under(bundle), bundle),
            "architectures": archs, "signatureVerification": "codesign --verify --deep --strict: passed (ad-hoc)",
            "signatureLog": str(signature_log), "signatureLogSHA256": sha(signature_log)
        })
    legacy = ["Sources/Models/AppState.swift", "Sources/Models/UsageData.swift",
              "Sources/Services/CodexService.swift", "Sources/Services/GeminiService.swift",
              "Sources/Services/ClaudeService.swift", "Sources/Services/UpdateCheckerService.swift",
              "Sources/Services/SelfUpdateService.swift", "Sources/Helpers/LaunchAtLoginHelper.swift"]
    manifest = {
        "generatedAt": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "provenance": "Captured sources before compilation; both candidates built in that snapshot; checked inputs before/after",
        "baseCommit": run("git", "rev-parse", "HEAD"), "workingTree": "uncommitted; archive and hashes identify inputs",
        "sourceTreeSHA256": tree_sha([snapshot / p for p in hashes], snapshot),
        "sourceArchive": str(archive), "sourceArchiveSHA256": sha(archive), "files": hashes,
        "compilerPath": str(compiler), "compilerSHA256": compiler_sha, "swift": swift_version,
        "sdkPath": str(sdk), "sdkVersion": sdk_settings.get("Version"),
        "sdkSettingsSHA256": sha(sdk / "SDKSettings.plist"),
        "macOS": run("sw_vers", "-productVersion"), "deploymentTarget": "macOS 13.0",
        "legacySourcesUnchangedFromBase": subprocess.run(["git", "diff", "--quiet", "HEAD", "--", *legacy], cwd=ROOT).returncode == 0,
        "bundles": bundles, "priorArtifacts": str(prior),
        "limitations": ["Verification substitutes account/update inputs and blocks account mutation/installation.",
                        "Product candidate compiled and signature-checked but not launched.",
                        "Intel hardware, real login and update installation are not exercised.",
                        "Lifecycle sleep tests post notifications; they do not suspend the Mac."]
    }
    (out / "build-manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    print(f"Built and recorded: {out / 'build-manifest.json'}", flush=True)


if __name__ == "__main__":
    main()
