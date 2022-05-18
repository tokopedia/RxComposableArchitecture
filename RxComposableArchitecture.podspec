#
# Be sure to run `pod lib lint RxComposableArchitecture.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'RxComposableArchitecture'
  s.version          = '0.1.0'
  s.summary          = 'A short description of RxComposableArchitecture.'
  s.description      = <<-DESC
TODO: Add long description of the pod here.
                       DESC

  s.homepage         = 'https://github.com/tokopedia/RxComposableArchitecture'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'tokopedia' => 'ios@tokopedia.com' }
  s.source           = { :git => 'https://github.com/tokopedia/RxComposableArchitecture.git', :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/tokopedia'

  s.ios.deployment_target = '11.0'

  s.source_files = [
    'Sources/RxComposableArchitecture/**/*'
  ]
  s.dependency 'RxSwift', '5.1.1'
  s.dependency 'RxCocoa', '5.1.1'
  s.dependency 'CasePaths'
  
end
