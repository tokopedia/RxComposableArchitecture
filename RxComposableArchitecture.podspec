#
# Be sure to run `pod lib lint RxComposableArchitecture.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'RxComposableArchitecture'
  s.version          = '0.17.0'
  s.summary          = 'The Composable Architecture (TCA, for short) is a library for building applications in a consistent and understandable way, with composition, testing, and ergonomics in mind.'
  s.description      = <<-DESC
  The Composable Architecture (TCA, for short) is a library for building applications in a consistent and understandable way, with composition, testing, and ergonomics in mind. 
  This library is based on PointFree's Swift Composable Architecture.
                       DESC

  s.homepage         = 'https://github.com/tokopedia/RxComposableArchitecture'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'tokopedia' => 'ios@tokopedia.com' }
  s.source           = { :git => 'https://github.com/tokopedia/RxComposableArchitecture.git', :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/tokopedia'

  s.ios.deployment_target = '13.0'

  s.source_files = [
    'Sources/RxComposableArchitecture/**/*',
  ]
  s.dependency 'RxSwift', '5.1.1'
  s.dependency 'RxCocoa', '5.1.1'
  s.dependency 'CasePaths'
  s.dependency 'XCTestDynamicOverlay'
  s.dependency 'CustomDump'
  s.dependency 'Dependencies'
  
end
