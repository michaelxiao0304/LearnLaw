#!/usr/bin/env python3
"""Generate the dependency-free Xcode project; all source paths stay inside ios/."""
from pathlib import Path
import hashlib, json
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parents[1]
objects = {}
class Ref(str): pass

def ident(name): return hashlib.sha256(name.encode()).hexdigest()[:24].upper()
def obj(object_name, isa, **values):
    key = ident(object_name)
    objects[key] = dict(isa=isa, **values)
    return Ref(key)
def serialize(value, level=0):
    if isinstance(value, Ref): return str(value)
    if isinstance(value, str): return json.dumps(value, ensure_ascii=False)
    if isinstance(value, int): return str(value)
    if isinstance(value, list): return '(' + ', '.join(serialize(v, level+1) for v in value) + ')'
    return '{\n' + ''.join('\t'*(level+1)+serialize(k)+' = '+serialize(v,level+1)+';\n' for k,v in value.items())+'\t'*level+'}'

def file_ref(path, kind):
    return obj('file:'+path, 'PBXFileReference', lastKnownFileType=kind, path=path, sourceTree='<group>')

source_refs = [file_ref(str(p.relative_to(ROOT)), 'sourcecode.swift') for p in sorted((ROOT/'LawSense').rglob('*.swift'))]
assets = file_ref('LawSense/Assets.xcassets','folder.assetcatalog')
fixture = [file_ref('DevelopmentContent/development-catalog.json','text.json'),file_ref('DevelopmentContent/development-catalog.sha256','text')]
unit_sources = [file_ref(str(p.relative_to(ROOT)),'sourcecode.swift') for p in sorted((ROOT/'LawSenseTests').glob('*.swift'))]
ui_sources = [file_ref(str(p.relative_to(ROOT)),'sourcecode.swift') for p in sorted((ROOT/'LawSenseUITests').glob('*.swift'))]

products=[]; targets=[]
project_settings=dict(SWIFT_VERSION='6.0', SWIFT_STRICT_CONCURRENCY='complete', IPHONEOS_DEPLOYMENT_TARGET='17.0', SDKROOT='iphoneos', CLANG_ENABLE_MODULES='YES', CODE_SIGN_STYLE='Automatic', ENABLE_USER_SCRIPT_SANDBOXING='YES', TARGETED_DEVICE_FAMILY='1,2')

def configurations(name, base, project=False):
    refs=[]
    for config in ['Debug','Release']:
        settings = dict(base)
        settings.update(SWIFT_OPTIMIZATION_LEVEL='-Onone' if config=='Debug' else '-O', DEBUG_INFORMATION_FORMAT='dwarf' if config=='Debug' else 'dwarf-with-dsym')
        settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = '$(inherited)' + (' DEBUG' if config=='Debug' else '') + (' DEVELOPMENT_CONTENT' if name=='LawSenseDevelopment' else '')
        settings['ENABLE_TESTABILITY'] = 'YES' if config=='Debug' else 'NO'
        refs.append(obj(name+':'+config,'XCBuildConfiguration',name=config,buildSettings=settings))
    return obj(name+':configs','XCConfigurationList',buildConfigurations=refs,defaultConfigurationIsVisible=0,defaultConfigurationName='Release')

def phase(name, kind, refs):
    builds=[obj(name+':'+str(r),'PBXBuildFile',fileRef=r) for r in refs]
    return obj(name,kind,buildActionMask=2147483647,files=builds,runOnlyForDeploymentPostprocessing=0)

def target(name, sources, resources, product_type, extra, app_target=None):
    extension='app' if product_type=='application' else 'xctest'
    product=obj(name+':product','PBXFileReference',explicitFileType='wrapper.application' if extension=='app' else 'wrapper.cfbundle',path=name+'.'+extension,sourceTree='BUILT_PRODUCTS_DIR')
    products.append(product)
    settings=dict(project_settings,PRODUCT_NAME=name,PRODUCT_BUNDLE_IDENTIFIER='com.lawsense.app' + ('' if name=='LawSense' else '.'+name.lower()),GENERATE_INFOPLIST_FILE='YES',MARKETING_VERSION='0.1.0',CURRENT_PROJECT_VERSION='1',SUPPORTED_PLATFORMS='iphoneos iphonesimulator',SUPPORTS_MACCATALYST='NO',LD_RUNPATH_SEARCH_PATHS='$(inherited) @executable_path/Frameworks',**extra)
    phases=[phase(name+':sources','PBXSourcesBuildPhase',sources),phase(name+':frameworks','PBXFrameworksBuildPhase',[]),phase(name+':resources','PBXResourcesBuildPhase',resources)]
    if name=='LawSense':
        phases.insert(0,obj(name+':release-gate','PBXShellScriptBuildPhase',buildActionMask=2147483647,files=[],inputPaths=[],outputPaths=[],runOnlyForDeploymentPostprocessing=0,shellPath='/bin/sh',shellScript='if [ "$CONFIGURATION" = "Release" ]; then\n  echo "error: D01/D02 approved content integration is required before a production Release build."\n  exit 1\nfi\n',alwaysOutOfDate=1))
    dependencies=[]
    if app_target:
        proxy=obj(name+':proxy','PBXContainerItemProxy',containerPortal=Ref(ident('project')),proxyType=1,remoteGlobalIDString=app_target,remoteInfo='LawSenseDevelopment')
        dependencies=[obj(name+':dependency','PBXTargetDependency',target=app_target,targetProxy=proxy)]
    result=obj(name,'PBXNativeTarget',name=name,productName=name,buildConfigurationList=configurations(name,settings),buildPhases=phases,buildRules=[],dependencies=dependencies,productReference=product,productType='com.apple.product-type.'+product_type)
    targets.append(result)
    return result

app_settings=dict(ASSETCATALOG_COMPILER_APPICON_NAME='AppIcon',INFOPLIST_KEY_CFBundleDisplayName='识法',INFOPLIST_KEY_UILaunchScreen_Generation='YES',INFOPLIST_KEY_UIApplicationSceneManifest_Generation='YES',INFOPLIST_KEY_UISupportedInterfaceOrientations='UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight',INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad='UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight')
production=target('LawSense',source_refs,[assets],'application',dict(app_settings,PRODUCT_MODULE_NAME='LawSense'))
dev=target('LawSenseDevelopment',source_refs,[assets,*fixture],'application',dict(app_settings,PRODUCT_MODULE_NAME='LawSenseDev',INFOPLIST_KEY_CFBundleDisplayName='识法·开发'))
unit=target('LawSenseTests',unit_sources,[],'bundle.unit-test',dict(TEST_HOST='$(BUILT_PRODUCTS_DIR)/LawSenseDevelopment.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/LawSenseDevelopment',BUNDLE_LOADER='$(TEST_HOST)'),dev)
ui=target('LawSenseUITests',ui_sources,[],'bundle.ui-testing',dict(TEST_TARGET_NAME='LawSenseDevelopment'),dev)
products_group=obj('products','PBXGroup',name='Products',children=products,sourceTree='<group>')
main_group=obj('main-group','PBXGroup',children=[*source_refs,assets,*fixture,*unit_sources,*ui_sources,products_group],sourceTree='<group>')
obj('project','PBXProject',attributes={'LastUpgradeCheck':'2700','BuildIndependentTargetsInParallel':'YES'},buildConfigurationList=configurations('project',project_settings),compatibilityVersion='Xcode 14.0',developmentRegion='zh-Hans',knownRegions=['zh-Hans','en','Base'],mainGroup=main_group,productRefGroup=products_group,projectDirPath='',projectRoot='',targets=targets)
project_dir=ROOT/'LawSense.xcodeproj'
project_dir.mkdir(exist_ok=True)
(project_dir/'project.pbxproj').write_text('// !$*UTF8*$!\n'+serialize(dict(archiveVersion=1,classes={},objectVersion=56,objects=objects,rootObject=Ref(ident('project'))))+'\n')

schemes=project_dir/'xcshareddata'/'xcschemes'
schemes.mkdir(parents=True,exist_ok=True)
for name,app,tests in [('LawSense',production,[]),('LawSenseDevelopment',dev,[('LawSenseTests',unit),('LawSenseUITests',ui)])]:
    def buildable(n,ref): return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{ref}" BuildableName="{escape(n)}.{"xctest" if "Tests" in n else "app"}" BlueprintName="{n}" ReferencedContainer="container:LawSense.xcodeproj"/>'
    entries = "".join(f'<BuildActionEntry buildForTesting="YES" buildForRunning="{runnable}" buildForProfiling="{runnable}" buildForArchiving="{runnable}" buildForAnalyzing="YES">{buildable(n,r)}</BuildActionEntry>' for n,r in [(name,app),*tests] for runnable in ["NO" if "Tests" in n else "YES"])
    testables=''.join(f'<TestableReference skipped="NO">{buildable(n,r)}</TestableReference>' for n,r in tests)
    xml=f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2700" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>{entries}</BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables>{testables}</Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{buildable(name,app)}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{buildable(name,app)}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/>
<ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
'''
    (schemes/(name+'.xcscheme')).write_text(xml)
print('Generated LawSense.xcodeproj with production, development and test targets')
