#
# Be sure to run `pod lib lint swift-collections.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'swift-collections'
  s.version          = '1.1.1'
  s.summary          = 'Swift Collections is an open-source package of data structure implementations for the Swift programming language.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
    Swift Collections is an open-source package of data structure implementations for the Swift programming language.
                       DESC

  s.homepage         = 'https://github.com/apple/swift-collections'
  s.license          = { :type => 'Apache', :file => 'LICENSE.txt' }
  s.author           = { 'Apple' => 'Apple' }
  s.source           = { :git => 'https://github.com/apple/swift-collections.git', :tag => s.version.to_s }

  s.ios.deployment_target = '12.0'
  s.swift_versions = ['5']

  s.module_name = 'Collections'

  s.subspec 'BitCollections' do |ss|
    ss.dependency "InternalCollectionsUtilities", "#{s.version}"
    ss.source_files = 'Sources/BitCollections/**/*.swift'
  end

  s.subspec 'DequeModule' do |ss|
    ss.dependency "InternalCollectionsUtilities", "#{s.version}"
    ss.source_files = 'Sources/DequeModule/*.swift'
  end

  s.subspec 'HashTreeCollections' do |ss|
    ss.dependency "InternalCollectionsUtilities", "#{s.version}"
    ss.source_files = 'Sources/HashTreeCollections/**/*.swift'
  end

  s.subspec 'HeapModule' do |ss|
    ss.dependency "InternalCollectionsUtilities", "#{s.version}"
    ss.source_files = 'Sources/HeapModule/*.swift'
  end

  s.subspec 'OrderedCollections' do |ss|
    ss.dependency "InternalCollectionsUtilities", "#{s.version}"
    ss.source_files = 'Sources/OrderedCollections/**/*.swift'
  end

end