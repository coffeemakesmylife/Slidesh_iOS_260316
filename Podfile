platform :ios, '14.0'

target 'Slidesh' do
  use_frameworks!

  pod 'Alamofire'
  pod 'Kingfisher'
  pod 'SkeletonView'
  pod 'ZXRequestBlock'
  pod 'lottie-ios'
  pod 'SnapKit'

end

# 强制所有 pod target 使用 iOS 14.0，并修复 Info.plist 缺少版本号的问题
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'
    end
  end

  # 修复 pod framework 的 Info.plist 缺少 CFBundleShortVersionString（ITMS-90057）
  installer.pods_project.targets.each do |target|
    plist_path = "#{installer.sandbox.root}/Target Support Files/#{target.name}/#{target.name}-Info.plist"
    next unless File.exist?(plist_path)
    system("/usr/libexec/PlistBuddy -c 'Add :CFBundleShortVersionString string 1.0' '#{plist_path}' 2>/dev/null || /usr/libexec/PlistBuddy -c 'Set :CFBundleShortVersionString 1.0' '#{plist_path}'")
    system("/usr/libexec/PlistBuddy -c 'Add :CFBundleVersion string 1' '#{plist_path}' 2>/dev/null || /usr/libexec/PlistBuddy -c 'Set :CFBundleVersion 1' '#{plist_path}'")
  end
end
