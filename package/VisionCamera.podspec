require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

nodeModules = File.join(File.dirname(`cd "#{Pod::Config.instance.installation_root.to_s}" && node --print "require.resolve('react-native/package.json')"`), '..')

enableFrameProcessors = true
if defined?($VCEnableFrameProcessors)
  Pod::UI.puts "[VisionCamera] $VCEnableFrameProcessors is set to #{$VCEnableFrameProcessors}!"
  enableFrameProcessors = $VCEnableFrameProcessors
end

enableLocation = true
if defined?($VCEnableLocation)
  Pod::UI.puts "[VisionCamera] $VCEnableLocation is set to #{$VCEnableLocation}!"
  enableLocation = $VCEnableLocation
else
  Pod::UI.puts "[VisionCamera] Building with CLLocation APIs as $VCEnableLocation is not set.."
end

Pod::UI.puts("[VisionCamera] node modules #{Dir.exist?(nodeModules) ? "found at #{nodeModules}" : "not found!"}")
workletsPath = File.join(nodeModules, "react-native-worklets-core")
hasWorklets = File.exist?(workletsPath) && enableFrameProcessors
Pod::UI.puts("[VisionCamera] react-native-worklets-core #{hasWorklets ? "found" : "not found"}, Frame Processors #{hasWorklets ? "enabled" : "disabled"}!")

Pod::Spec.new do |s|
  s.name         = "VisionCamera"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.description  = package["description"]
  s.homepage     = package["homepage"]
  s.license      = package["license"]
  s.authors      = package["author"]

  s.platforms    = { :ios => "12.4" }
  s.source       = { :git => "https://github.com/mrousavy/react-native-vision-camera.git", :tag => "#{s.version}" }

  s.pod_target_xcconfig = {
    "GCC_PREPROCESSOR_DEFINITIONS" => "$(inherited) VISION_CAMERA_ENABLE_FRAME_PROCESSORS=#{hasWorklets}",
    "SWIFT_ACTIVE_COMPILATION_CONDITIONS" => "$(inherited) #{hasWorklets ? "VISION_CAMERA_ENABLE_FRAME_PROCESSORS" : ""} #{enableLocation ? "VISION_CAMERA_ENABLE_LOCATION" : ""}",
  }

  s.requires_arc = true

  s.dependency "React"
  s.dependency "React-Core"
  s.dependency "React-callinvoker"

  s.subspec 'Core' do |core|
    # VisionCamera Core Swift codebase
    core.source_files = [
      "ios/*.{m,mm,swift}",
      "ios/Core/*.{m,mm,swift}",
      "ios/Extensions/*.{m,mm,swift}",
      "ios/Parsers/*.{m,mm,swift}",
      "ios/React Utils/*.{m,mm,swift}",
      "ios/Types/*.{m,mm,swift}",
      "ios/CameraBridge.h",
    ]
    s.preserve_paths = "ios/**/*.h"
  end

  s.subspec 'FrameProcessors' do |fp|
    # VisionCamera Frame Processors C++ codebase (optional)
    fp.dependency "VisionCamera/Core"
    fp.dependency "react-native-worklets-core"

    fp.source_files = [
      "ios/Frame Processor/*.{h,m,mm}",
      "cpp/**/*.{h,cpp}"
    ]

    fp.preserve_paths = [
      "cpp/**/*.h",
      "ios/Frame Processor/*.h"
    ]

    fp.pod_target_xcconfig = {
      "CLANG_CXX_LANGUAGE_STANDARD" => "c++17",
      "HEADER_SEARCH_PATHS" => "\"$(PODS_TARGET_SRCROOT)/cpp/\"/** "
    }
  end
end
