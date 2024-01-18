# frozen_string_literal: true

require_relative "lib/remote_entity/version"

Gem::Specification.new do |spec|
  spec.name = "remote_entity"
  spec.version = RemoteEntity::VERSION
  spec.authors = ["Kuroun Seung"]
  spec.email = ["kuroun.seung@gmail.com"]

  spec.summary = "Using configuration style to generate Ruby classes and methods that wrap the API calls to a remote service."
  spec.homepage = "https://github.com/kseung-gpsw/remote_entity"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/kseung-gpsw/remote_entity"
  spec.metadata["changelog_uri"] = "https://github.com/kseung-gpsw/remote_entity/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) || f.start_with?(*%w[bin/ test/ spec/ features/ .git]) || f.end_with?(".gem")
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  spec.add_dependency "cgi", "~> 0.2"
  spec.add_dependency "oauth2", "~> 2.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
