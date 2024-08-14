Pod::Spec.new do |spec|
  spec.name = "OrderedCollections"
  spec.version = "1.0.4"
  spec.summary = "Swift Collections is an open-source package of data structure implementations for the Swift programming language."
  spec.description  = <<-DESC
  Swift Collections is an open-source package of data structure implementations for the Swift programming language.
  DESC

  spec.homepage = "https://github.com/apple/swift-collections"
  spec.license = { :type => "Apache-2.0 License", :file => "swift-collections/LICENSE.txt" }
  spec.author = { "Apple" => "" }
  
  spec.ios.deployment_target = "13.0"
  spec.osx.deployment_target = "10.15"
  spec.watchos.deployment_target = "6.0"
  spec.tvos.deployment_target = "13.0"
  spec.swift_version = '5.5'
  
  spec.source = { :git => "https://github.com/apple/swift-collections.git", :tag => "#{spec.version}" }
  spec.source_files = "swift-collections/Sources/OrderedCollections/**/*.swift"
end