Pod::Spec.new do |s|
  s.name         = "CustomDump"
  s.version      = "0.9.1"   
  s.summary      = "A collection of tools for debugging, diffing, and testing your application's data structures."
  s.description  = <<-DESC
    A collection of tools for debugging, diffing, and testing your application's data structures.
  DESC
  s.homepage     = "https://github.com/pointfreeco/swift-custom-dump"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.author             = { "PointFree" => "support@pointfree.co" }
  s.social_media_url   = "http://twitter.com/pointfreeco"
  s.ios.deployment_target = "13.0"
  s.osx.deployment_target = '10.15'
  s.source       = { :git => "https://github.com/pointfreeco/swift-custom-dump.git", :tag => s.version.to_s }
  s.ios.source_files  = "Sources/CustomDump/**/*.swift"
  s.macos.source_files  = "Sources/CustomDump/**/*.swift"
  s.swift_version = "5.0"
  s.dependency "XCTestDynamicOverlay"
end
