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

# 强制所有 pod target 使用 iOS 14.0，避免 libarclite 报错
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'
    end
  end
end
