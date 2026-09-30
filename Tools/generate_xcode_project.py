"""Generate a small, deterministic Xcode project for the four release app targets."""

from hashlib import sha1
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "TimeBite.xcodeproj" / "project.pbxproj"


def ident(name):
    return sha1(name.encode()).hexdigest().upper()[:24]


objects = {}


def add(label, isa, **properties):
    key = ident(label)
    objects[key] = {"isa": isa, **properties}
    return key


def render(value, depth=0):
    indent = "\t" * depth
    if isinstance(value, dict):
        lines = ["{"]
        for key, item in value.items():
            lines.append(f"{indent}\t{key} = {render(item, depth + 1)};")
        lines.append(f"{indent}}}")
        return "\n".join(lines)
    if isinstance(value, list):
        return "(\n" + "".join(f"{indent}\t{render(item, depth + 1)},\n" for item in value) + f"{indent})"
    if isinstance(value, str):
        escaped = value.replace("\\", "\\\\").replace('"', '\\"')
        return f'"{escaped}"'
    return str(value)


package = add("local package", "XCLocalSwiftPackageReference", relativePath=".")
products = {}
for name in ("TimeBiteCore", "TimeBiteData", "TimeBiteUI", "TimeBiteHealth"):
    products[name] = add(f"package {name}", "XCSwiftPackageProductDependency", productName=name, package=package)

platforms = (
    ("TimeBiteMac", "macosx", "MACOSX_DEPLOYMENT_TARGET", "14.0", "6", "macosx", "com.timebite.official.mac"),
    ("TimeBiteiOS", "iphoneos", "IPHONEOS_DEPLOYMENT_TARGET", "17.0", "1,2", "iphoneos iphonesimulator", "com.timebite.official.ios"),
    ("TimeBiteWatch", "watchos", "WATCHOS_DEPLOYMENT_TARGET", "10.0", "4", "watchos watchsimulator", "com.timebite.official.watchkitapp"),
    ("TimeBiteVision", "xros", "XROS_DEPLOYMENT_TARGET", "1.0", "7", "xros xrsimulator", "com.timebite.official.vision"),
)

groups = []
targets = []
file_refs = []
target_attributes = {}
for name, sdk, deployment_key, deployment, family, supported, bundle in platforms:
    group = add(f"{name} files", "PBXFileSystemSynchronizedRootGroup", path=f"Apps/{name}", sourceTree="<group>")
    groups.append(group)
    product = add(f"{name} app", "PBXFileReference", explicitFileType="wrapper.application", includeInIndex=0,
                  path=f"{name}.app", sourceTree="BUILT_PRODUCTS_DIR")
    file_refs.append(product)
    source = add(f"{name} sources", "PBXSourcesBuildPhase", buildActionMask=2147483647, files=[], runOnlyForDeploymentPostprocessing=0)
    target_products = ["TimeBiteCore", "TimeBiteData", "TimeBiteUI"]
    if name == "TimeBiteiOS":
        target_products.append("TimeBiteHealth")
    framework_files = [add(f"{name} {lib} build file", "PBXBuildFile", productRef=products[lib])
                       for lib in target_products]
    frameworks = add(f"{name} frameworks", "PBXFrameworksBuildPhase", buildActionMask=2147483647,
                     files=framework_files, runOnlyForDeploymentPostprocessing=0)
    resources = add(f"{name} resources", "PBXResourcesBuildPhase", buildActionMask=2147483647,
                    files=[], runOnlyForDeploymentPostprocessing=0)
    config_ids = []
    for configuration in ("Debug", "Release"):
        settings = {
            "ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS": "YES",
            "GENERATE_INFOPLIST_FILE": "YES",
            "INFOPLIST_KEY_CFBundleDisplayName": "TimeBite",
            "PRODUCT_BUNDLE_IDENTIFIER": bundle,
            "PRODUCT_NAME": name,
            "SDKROOT": sdk,
            "SUPPORTED_PLATFORMS": supported,
            "SWIFT_VERSION": "5.0",
            "TARGETED_DEVICE_FAMILY": family,
            deployment_key: deployment,
        }
        if name == "TimeBiteMac":
            settings["CODE_SIGNING_ALLOWED"] = "NO"
            settings["ENABLE_APP_SANDBOX"] = "YES"
        if name == "TimeBiteiOS":
            settings["CODE_SIGN_STYLE"] = "Automatic"
            settings["DEVELOPMENT_TEAM"] = "YBBYS93T5A"
            settings["CODE_SIGN_ENTITLEMENTS"] = "Apps/TimeBiteiOS/TimeBiteiOS.entitlements"
            settings["INFOPLIST_KEY_NSCameraUsageDescription"] = (
                "TimeBite uses the camera to scan handwritten plans you choose to import."
            )
            settings["INFOPLIST_KEY_NSCalendarsFullAccessUsageDescription"] = (
                "TimeBite displays your existing calendar events beside planned focus blocks so you can schedule without conflicts."
            )
            settings["INFOPLIST_KEY_NSHealthShareUsageDescription"] = (
                "TimeBite uses your sleep and workout duration to show how your day is allocated."
            )
            settings["INFOPLIST_KEY_UILaunchScreen_Generation"] = "YES"
            settings["INFOPLIST_KEY_UISupportedInterfaceOrientations"] = (
                "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown "
                "UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight"
            )
            settings["INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad"] = settings[
                "INFOPLIST_KEY_UISupportedInterfaceOrientations"
            ]
        if name == "TimeBiteWatch":
            settings["CODE_SIGNING_ALLOWED"] = "NO"
            settings["INFOPLIST_KEY_WKWatchKitApp"] = "YES"
        if name == "TimeBiteVision":
            settings["CODE_SIGNING_ALLOWED"] = "NO"
        config_ids.append(add(f"{name} {configuration}", "XCBuildConfiguration", name=configuration,
                              buildSettings=settings))
    config_list = add(f"{name} config list", "XCConfigurationList", buildConfigurations=config_ids,
                      defaultConfigurationIsVisible=0, defaultConfigurationName="Release")
    target = add(f"{name} target", "PBXNativeTarget", buildConfigurationList=config_list,
                 buildPhases=[source, frameworks, resources], buildRules=[], dependencies=[],
                 fileSystemSynchronizedGroups=[group], name=name, packageProductDependencies=list(products.values()),
                 productName=name, productReference=product, productType="com.apple.product-type.application")
    targets.append(target)
    if name == "TimeBiteiOS":
        target_attributes[target] = {
            "CreatedOnToolsVersion": "16.0",
            "SystemCapabilities": {
                "com.apple.HealthKit": {"enabled": 1},
                "com.apple.SignInWithApple": {"enabled": 1},
            },
        }

product_group = add("products group", "PBXGroup", children=file_refs, name="Products", sourceTree="<group>")
main_group = add("main group", "PBXGroup", children=[*groups, product_group], sourceTree="<group>")
project_configs = []
for configuration in ("Debug", "Release"):
    project_configs.append(add(f"project {configuration}", "XCBuildConfiguration", name=configuration,
                               buildSettings={"CLANG_ENABLE_MODULES": "YES", "SWIFT_VERSION": "5.0"}))
project_config_list = add("project config list", "XCConfigurationList", buildConfigurations=project_configs,
                          defaultConfigurationIsVisible=0, defaultConfigurationName="Release")
project = add("project", "PBXProject", attributes={"BuildIndependentTargetsInParallel": 1,
              "LastUpgradeCheck": "2700", "TargetAttributes": target_attributes}, buildConfigurationList=project_config_list,
              compatibilityVersion="Xcode 16.0", developmentRegion="en", hasScannedForEncodings=0,
              knownRegions=["en", "Base"], mainGroup=main_group, packageReferences=[package],
              preferredProjectObjectVersion=77, productRefGroup=product_group, projectDirPath="",
              projectRoot="", targets=targets)

document = {"archiveVersion": 1, "classes": {}, "objectVersion": 77, "objects": objects,
            "rootObject": project}
OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text("// !$*UTF8*$!\n" + render(document) + "\n")
print(OUT)
