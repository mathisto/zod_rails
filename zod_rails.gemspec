# frozen_string_literal: true

require_relative "lib/zod_rails/version"

Gem::Specification.new do |spec|
  spec.name = "zod_rails"
  spec.version = ZodRails::VERSION
  spec.authors = ["Matt Kelly"]
  spec.email = ["matthew.ryan.kelly@gmail.com"]

  spec.summary = "Generate Zod schemas from ActiveRecord models"
  spec.description = "Ruby gem that introspects ActiveRecord models and generates TypeScript files with Zod schemas for type-safe frontend validation"
  spec.homepage = "https://github.com/mathisto/zod_rails"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/mathisto/zod_rails"
  spec.metadata["changelog_uri"] = "https://github.com/mathisto/zod_rails/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .rubocop.yml])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "logger", "~> 1.6"
end
