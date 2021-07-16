#!/usr/bin/env ruby
# A script to generate the .jenkins.yml file for the CI pull request job
XCODE_VERSIONS = %w(12.2 12.4 12.5.1 13.0)

all = ->(v) { true }
latest_only = ->(v) { v == XCODE_VERSIONS.last }
oldest_and_latest = ->(v) { v == XCODE_VERSIONS.first or v == XCODE_VERSIONS.last }

def minimum_version(major)
  ->(v) { v.split('.').first.to_i >= major }
end

targets = {
  'docs' => latest_only,
  'swiftlint' => latest_only,

  'osx' => all,
  'osx-encryption' => oldest_and_latest,
  'osx-object-server' => oldest_and_latest,

  'swiftpm' => all,
  'swiftpm-debug' => all,
  'swiftpm-address' => latest_only,
  'swiftpm-thread' => latest_only,
  'swiftpm-ios' => latest_only,

  'ios-static' => oldest_and_latest,
  'ios-dynamic' => oldest_and_latest,
  'watchos' => oldest_and_latest,
  'tvos' => oldest_and_latest,

  'osx-swift' => all,
  'ios-swift' => oldest_and_latest,
  'tvos-swift' => oldest_and_latest,

  'osx-swift-evolution' => latest_only,
  'ios-swift-evolution' => latest_only,
  'tvos-swift-evolution' => latest_only,

  'catalyst' => oldest_and_latest,
  'catalyst-swift' => oldest_and_latest,

  'xcframework' => latest_only,

  'cocoapods-osx' => all,
  'cocoapods-ios' => oldest_and_latest,
  'cocoapods-ios-dynamic' => oldest_and_latest,
  'cocoapods-watchos' => oldest_and_latest,
  # 'cocoapods-catalyst' => oldest_and_latest,
  'swiftui-ios' => latest_only,
  'swiftui-server-osx' => latest_only,
}

output_file = """
# Yaml Axis Plugin
# https://wiki.jenkins-ci.org/display/JENKINS/Yaml+Axis+Plugin
# This is a generated file produced by scripts/pr-ci-matrix.rb.

xcode_version:#{XCODE_VERSIONS.map { |v| "\n - #{v}" }.join()}
target:#{targets.map { |k, v| "\n - #{k}" }.join()}
configuration:
 - N/A

exclude:
"""
targets.each { |name, filter|
  XCODE_VERSIONS.each { |version|
    if not filter.call(version)
      output_file << """
  - xcode_version: #{version}
    target: #{name}
"""
    end
  }
}

File.open('.jenkins.yml', "w") do |file|
  file.puts output_file
end
