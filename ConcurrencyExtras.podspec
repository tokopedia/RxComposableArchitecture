Pod::Spec.new do |s|
  s.name             = 'ConcurrencyExtras'
  s.version          = '0.17.0'
  s.summary          = 'local pod'

  s.homepage         = 'https://github.com/pointfreeco/swift-case-paths'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'PointFree' => 'support@pointfree.co' }
  s.source           = { :git => 'https://github.com/tokopedia/RxComposableArchitecture.git', :branch => 'fix_cocoapods' }

  s.ios.deployment_target = '13.0'
  s.swift_version = '5.0'

  s.source_files = 'swift-concurrency-extras/Sources/ConcurrencyExtras/**/*.swift'
end