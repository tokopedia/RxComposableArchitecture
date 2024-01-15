Pod::Spec.new do |s|
    s.name             = 'ConcurrencyExtras'
    s.version          = '1.0.0'
    s.summary          = 'local pod'
  
    s.homepage         = 'https://github.com/pointfreeco/swift-concurrency-extras'
    s.license          = { :type => 'MIT', :file => 'LICENSE' }
    s.author           = { 'PointFree' => 'support@pointfree.co' }
    s.source           = { :git => 'https://github.com/pointfreeco/swift-concurrency-extras.git', :tag => s.version.to_s }
  
    s.ios.deployment_target = '13.0'
    s.swift_version = '5.0'
  
    s.source_files = 'swift-concurrency-extras/Sources/ConcurrencyExtras/**/*.swift'
  end