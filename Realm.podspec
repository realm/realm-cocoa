Pod::Spec.new do |s|
  s.name                  = "Realm"
  s.version               = `sh build.sh get-version`
  s.summary               = "Realm is a modern data framework & database for iOS & OSX."
  s.description           = <<-DESC
                            Realm is a modern data framework & database for iOS & OSX. You can use it purely in memory — or persist to disk with extraordinary performance.

                            Realm’s data structures look like NSObjects and NSArrays, but provide additional features such as: querying, relationships & graphs, thread safety, and more.

                            Realm is not built on SQLite. Instead, a custom C++ core is used to provide memory-efficient access to your data by using Realm objects, which usually consume less RAM than native objects. The core also provides an optional persistence layer that can automatically save and retrieve your objects from disk.

                            Realm offers extraordinary performance compared to SQLite and other persistence solutions. It has been in development since 2011 and powers an app with over 1 million
                            daily active users at a major mobile game company.
                            DESC
  s.homepage              = "http://realm.io"
  s.source                = { :http => "http://static.realm.io/downloads/cocoa/realm-cocoa-#{s.version}.zip" }
  s.author                = { "Realm" => "help@realm.io" }
  s.ios.deployment_target = "6.0"
  s.osx.deployment_target = "10.8"
  s.library               = "c++"
  s.requires_arc          = true
  s.social_media_url      = "https://twitter.com/realm"
  s.documentation_url     = "http://realm.io/docs/ios/#{s.version}"
  s.ios.vendored_frameworks = "ios/Realm.framework"
  s.osx.vendored_frameworks = "osx/Realm.framework"
  s.license                 = { :type => 'Apache 2.0', :file => "ios/Realm.framework/Resources/LICENSE" }
end
