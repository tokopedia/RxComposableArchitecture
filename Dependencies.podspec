Pod::Spec.new do |s|
  s.name             = 'Dependencies'
  s.version          = '0.2.0'
  s.summary          = 'local pod'

  s.homepage         = 'https://github.com/pointfreeco/swift-dependencies'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'local pod' => 'ios@tokopedia.com' }
  s.source           = { :git => 'https://github.com/pointfreeco/swift-dependencies', :tag => s.version.to_s }

  s.ios.deployment_target = '13.0'
  s.swift_version = '5.0'

  s.source_files = [
    'Sources/**/*.swift',
  ]
end