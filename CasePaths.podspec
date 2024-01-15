Pod::Spec.new do |s|
  s.name             = 'CasePaths'
  s.version          = '0.8.1'
  s.summary          = 'local pod'

  s.homepage         = 'https://github.com/pointfreeco/swift-case-paths'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'local pod' => 'ios@tokopedia.com' }
  s.source           = { :git => 'https://github.com/pointfreeco/swift-case-paths', :tag => s.version.to_s }

  s.ios.deployment_target = '13.0'
  s.swift_version = '5.0'

  s.source_files = [
    'Sources/CasePaths/**/*.swift',
  ]
end