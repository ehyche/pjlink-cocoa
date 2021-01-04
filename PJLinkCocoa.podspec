Pod::Spec.new do |s|
  s.name         = 'PJLinkCocoa'
  s.version      = '0.9.9'
  s.license      = 'MIT'
  s.summary      = 'A Cocoa Library for communicating with projectors and other devices that implement the PJLink protocol.'
  s.homepage     = 'https://github.com/ehyche/pjlink-cocoa'
  s.author       = { "Eric Hyche" => "ehyche@gmail.com" }
  s.source       = { :git => "https://github.com/ehyche/pjlink-cocoa.git", :tag => '0.9.9' }
  s.source_files = 'PJLinkCocoa'
  s.requires_arc = true
  s.platform     = :ios, '14.3'
  s.frameworks   = 'CoreServices', 'SystemConfiguration', 'Security'
  s.dependency 'AFNetworking', '~> 1.3.0'
  s.dependency 'CocoaAsyncSocket/RunLoop', '7.5.1'
end
