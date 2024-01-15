Pod::Spec.new do |s|
  s.name             = 'Clocks'
  s.version          = '0.17.0'
  s.summary          = 'local pod'

  s.homepage         = 'https://github.com/pointfreeco/swift-clocks'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'PointFree' => 'support@pointfree.co' }
  s.source           = { :git => 'https://github.com/tokopedia/RxComposableArchitecture.git', :tag => s.version.to_s }

  s.ios.deployment_target = '13.0'
  s.swift_version = '5.0'

  s.source_files = 'swift-clocks/Sources/Clocks/**/*.swift'

  s.dependency 'ConcurrencyExtras'
end