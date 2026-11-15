#!/usr/bin/env python3
"""Attach the tracked WidgetKit sources to a Godot-exported Xcode project.

No third-party Python/Ruby modules. Apple's plutil parses the OpenStep project;
Xcode also accepts the XML plist written here. Rerunning updates sources without
duplicating targets, build phases, dependencies or the native startup hook.
"""
import argparse
import hashlib
import json
import plistlib
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def install(project: Path, godot: str, app_group: str | None = None):
    project = project.resolve()
    pbx_path = project / "project.pbxproj"
    pbx = json.loads(subprocess.check_output(["plutil", "-convert", "json", "-o", "-", str(pbx_path)]))
    objects = pbx["objects"]
    root = objects[pbx["rootObject"]]
    applications = [(key, obj) for key, obj in objects.items()
                    if obj.get("productType") == "com.apple.product-type.application"]
    if len(applications) != 1:
        raise ValueError("Expected exactly one application target")
    app_id, app = applications[0]
    configs = [objects[key] for key in objects[app["buildConfigurationList"]]["buildConfigurations"]]
    settings = configs[0]["buildSettings"]
    bundle = settings["PRODUCT_BUNDLE_IDENTIFIER"]
    group = app_group or "group." + bundle
    if not group.startswith("group."):
        raise ValueError("App Group identifier must start with group.")
    export = project.parent
    app_info = export / settings["INFOPLIST_FILE"]
    app_entitlements = export / settings["CODE_SIGN_ENTITLEMENTS"]
    dummy = export / app["name"] / "dummy.cpp"
    hook = "void godot_apple_embedded_plugins_initialize() {"
    dummy_text = dummy.read_text()
    if hook not in dummy_text:
        raise ValueError("Godot native initialization hook changed; refusing to patch")

    native = export / "YuFriendNative"
    for folder in ("Shared", "App", "Widget"):
        shutil.copytree(ROOT / "native/ios" / folder, native / folder, dirs_exist_ok=True)
    subprocess.run([godot, "--headless", "--path", str(ROOT), "--log-file", str(export / "widget-art.log"),
                    "--script", "res://tools/prepare_widget_art.gd", "--", str(native / "Resources")], check=True)

    def write_plist(path, value):
        path.write_bytes(plistlib.dumps(value, sort_keys=False))

    entitlements = plistlib.loads(app_entitlements.read_bytes())
    groups = entitlements.setdefault("com.apple.security.application-groups", [])
    if group not in groups:
        groups.append(group)
    write_plist(app_entitlements, entitlements)
    info = plistlib.loads(app_info.read_bytes())
    info["YuFriendAppGroup"] = group
    write_plist(app_info, info)
    write_plist(native / "Widget/Widget.entitlements", {"com.apple.security.application-groups": [group]})
    write_plist(native / "Widget/Info.plist", {
        "CFBundleDisplayName": "YuFriend", "CFBundleExecutable": "$(EXECUTABLE_NAME)",
        "CFBundleIdentifier": "$(PRODUCT_BUNDLE_IDENTIFIER)", "CFBundleName": "$(PRODUCT_NAME)",
        "CFBundlePackageType": "XPC!", "CFBundleInfoDictionaryVersion": "6.0",
        "CFBundleShortVersionString": "$(MARKETING_VERSION)", "CFBundleVersion": "$(CURRENT_PROJECT_VERSION)",
        "YuFriendAppGroup": group, "NSExtension": {"NSExtensionPointIdentifier": "com.apple.widgetkit-extension"},
    })
    if 'extern "C" void yufriend_widget_start();' not in dummy_text:
        dummy_text = dummy_text.replace(hook, 'extern "C" void yufriend_widget_start();\n\n' + hook + '\n    yufriend_widget_start();', 1)
        dummy.write_text(dummy_text)

    def add(name, value):
        key = hashlib.sha256(("YuFriendWidget:" + name).encode()).hexdigest()[:24].upper()
        objects[key] = value
        return key

    def append_unique(items, value):
        if value not in items:
            items.append(value)

    files = {}
    for filename, filetype in {
        "Shared/PetSnapshot.swift": "sourcecode.swift",
        "App/PetWidgetBridge.swift": "sourcecode.swift",
        "Widget/PetWidget.swift": "sourcecode.swift",
        "Resources/puppy-idle.png": "image.png",
        "Resources/puppy-sleep.png": "image.png",
    }.items():
        files[filename] = add(filename, {"isa": "PBXFileReference", "lastKnownFileType": filetype,
                                         "path": filename, "sourceTree": "<group>"})
    native_group = add("group", {"isa": "PBXGroup", "children": list(files.values()),
                                  "path": "YuFriendNative", "sourceTree": "<group>"})
    append_unique(objects[root["mainGroup"]]["children"], native_group)

    def build_file(filename, target):
        return add(target + ":" + filename, {"isa": "PBXBuildFile", "fileRef": files[filename]})

    app_sources = next(objects[phase] for phase in app["buildPhases"] if objects[phase]["isa"] == "PBXSourcesBuildPhase")
    for filename in ("Shared/PetSnapshot.swift", "App/PetWidgetBridge.swift"):
        append_unique(app_sources["files"], build_file(filename, "app"))

    def phase(name, kind, content):
        return add(name, {"isa": kind, "buildActionMask": 2147483647, "files": content,
                          "runOnlyForDeploymentPostprocessing": 0})

    sources = phase("sources", "PBXSourcesBuildPhase", [build_file(f, "widget") for f in
                    ("Shared/PetSnapshot.swift", "Widget/PetWidget.swift")])
    resources = phase("resources", "PBXResourcesBuildPhase", [build_file(f, "widget") for f in
                      ("Resources/puppy-idle.png", "Resources/puppy-sleep.png")])
    frameworks = phase("frameworks", "PBXFrameworksBuildPhase", [])
    product = add("product", {"isa": "PBXFileReference", "explicitFileType": "wrapper.app-extension",
                              "includeInIndex": 0, "path": "YuFriendWidget.appex", "sourceTree": "BUILT_PRODUCTS_DIR"})
    append_unique(objects[root["productRefGroup"]]["children"], product)
    widget_configs = []
    for config in configs:
        s = config["buildSettings"]
        widget_configs.append(add("config:" + config["name"], {
            "isa": "XCBuildConfiguration", "name": config["name"], "buildSettings": {
                "PRODUCT_NAME": "YuFriendWidget", "PRODUCT_BUNDLE_IDENTIFIER": bundle + ".widget",
                "DEVELOPMENT_TEAM": s["DEVELOPMENT_TEAM"], "CODE_SIGN_STYLE": "Automatic",
                "CODE_SIGN_ENTITLEMENTS": "YuFriendNative/Widget/Widget.entitlements",
                "INFOPLIST_FILE": "YuFriendNative/Widget/Info.plist", "SWIFT_VERSION": "5.0",
                "IPHONEOS_DEPLOYMENT_TARGET": "16.0", "TARGETED_DEVICE_FAMILY": "1",
                "SKIP_INSTALL": "YES", "APPLICATION_EXTENSION_API_ONLY": "YES",
                "MARKETING_VERSION": s["MARKETING_VERSION"], "CURRENT_PROJECT_VERSION": s["CURRENT_PROJECT_VERSION"],
                "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks", "@executable_path/../../Frameworks"],
                "SWIFT_OPTIMIZATION_LEVEL": "-Onone" if config["name"] == "Debug" else "-O",
                "GENERATE_INFOPLIST_FILE": "NO", "CLANG_ENABLE_MODULES": "YES",
            }}))
        s["ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES"] = "YES"
    config_list = add("configs", {"isa": "XCConfigurationList", "buildConfigurations": widget_configs,
                                  "defaultConfigurationIsVisible": 0, "defaultConfigurationName": "Debug"})
    target = add("target", {"isa": "PBXNativeTarget", "name": "YuFriendWidget", "productName": "YuFriendWidget",
                            "productReference": product, "productType": "com.apple.product-type.app-extension",
                            "buildConfigurationList": config_list, "buildPhases": [sources, frameworks, resources],
                            "buildRules": [], "dependencies": []})
    append_unique(root["targets"], target)
    proxy = add("proxy", {"isa": "PBXContainerItemProxy", "containerPortal": pbx["rootObject"],
                          "proxyType": 1, "remoteGlobalIDString": target, "remoteInfo": "YuFriendWidget"})
    dependency = add("dependency", {"isa": "PBXTargetDependency", "target": target, "targetProxy": proxy})
    append_unique(app["dependencies"], dependency)
    embedded = add("embedded", {"isa": "PBXBuildFile", "fileRef": product,
                                "settings": {"ATTRIBUTES": ["RemoveHeadersOnCopy"]}})
    embed_phase = add("embed", {"isa": "PBXCopyFilesBuildPhase", "buildActionMask": 2147483647,
                                "dstPath": "", "dstSubfolderSpec": 13, "files": [embedded],
                                "name": "Embed App Extensions", "runOnlyForDeploymentPostprocessing": 0})
    append_unique(app["buildPhases"], embed_phase)
    attributes = root.setdefault("attributes", {}).setdefault("TargetAttributes", {})
    for target_id in (app_id, target):
        capabilities = attributes.setdefault(target_id, {}).setdefault("SystemCapabilities", {})
        capabilities["com.apple.ApplicationGroups.iOS"] = {"enabled": 1}
    write_plist(pbx_path, pbx)
    print(f"Widget ready: {project}\nApp Group: {group}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("project", type=Path, help="Path to exported YuFriend.xcodeproj")
    parser.add_argument("--godot", default="/Applications/Godot.app/Contents/MacOS/Godot")
    parser.add_argument("--app-group", help="Override the default group.<app bundle ID>")
    args = parser.parse_args()
    install(args.project, args.godot, args.app_group)
