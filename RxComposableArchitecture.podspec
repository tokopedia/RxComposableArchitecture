#
# Be sure to run `pod lib lint RxComposableArchitecture.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'RxComposableArchitecture'
  s.version          = '0.1.0'
  s.summary          = 'A short description of RxComposableArchitecture.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
TODO: Add long description of the pod here.
                       DESC

  s.homepage         = 'https://github.com/andreyyoshua/RxComposableArchitecture'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'andreyyoshua' => 'andrey.yoshua@gmail.com' }
  s.source           = { :git => 'https://github.com/andreyyoshua/RxComposableArchitecture.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '10.0'

  s.source_files = [
    'RxComposableArchitecture/Classes/**/*',
    'DiffingInterface/**/*.swift',
    'DiffingUtility/**/*.swift'
  ]
  
  # s.resource_bundles = {
  #   'RxComposableArchitecture' => ['RxComposableArchitecture/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  s.dependency 'RxSwift', '5.1.1'
  s.dependency 'RxCocoa', '5.1.1'
  s.dependency 'CasePaths'
  
#  s.subspec 'DiffingInterface' do |diffingInterface|
#      diffingInterface.dependency 'Alamofire'
#      diffingInterface.source_files = 'DiffingInterface/**/*.swift'
#  end
#
#  s.subspec 'DiffingUtility' do |diffingUtility|
#      diffingUtility.source_files = 'DiffingUtility/**/*.swift'
#  end
  
end
