Pod::Spec.new do |s|
  s.name             = 'XCTestDynamicOverlay'
  s.version          = '0.8.5'
  s.summary          = 'local pod'

  s.homepage         = 'https://github.com/pointfreeco/xctest-dynamic-overlay'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'PointFree' => 'support@pointfree.co' }
  s.source           = { :git => 'https://github.com/pointfreeco/xctest-dynamic-overlay.git', :tag => s.version.to_s }

  s.ios.deployment_target = '13.0'
  s.swift_version = '5.0'

  s.source_files = 'xctest-dynamic-overlay/Sources/**/*.swift'
end