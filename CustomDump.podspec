Pod::Spec.new do |s|
  s.name             = 'CustomDump'
  s.version          = '0.17.0'
  s.summary          = 'A collection of tools for debugging, diffing, and testing your application\'s data structures.'
  s.description      = <<-DESC
  A collection of tools for debugging, diffing, and testing your application's data structures.
                       DESC

  s.homepage         = 'https://github.com/pointfreeco/swift-custom-dump'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'PointFree' => 'support@pointfree.co' }
  s.source           = { :git => 'https://github.com/tokopedia/RxComposableArchitecture.git', :branch => 'fix_cocoapods' }

  s.ios.deployment_target = '13.0'
  s.osx.deployment_target = '10.15'
  s.swift_version = '5.0'

  s.source_files = [
    'swift-custom-dump/Sources/CustomDump/**/*.swift',
  ]

  s.dependency 'XCTestDynamicOverlay'
end