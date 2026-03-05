# frozen_string_literal: true

require_relative "lib/sqinky/version"

Gem::Specification.new do |spec|
  spec.name = "sqinky"
  spec.version = Sqinky::VERSION
  spec.authors = ["David Uhlig"]
  spec.email = ["david.uhlig@gmail.com"]

  spec.summary = "Add Sqids-based identifier encoding/decoding helpers to Active Record models."
  spec.description = <<~DESC
    Sqinky adds a thin access layer on top of Sqids to work effortlessly with Sqids in Active Record models. It supports encodings composed of multiple attributes, and multiple encodings per model.
  DESC
  spec.homepage = "https://github.com/david-uhlig/sqinky"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "https://github.com/david-uhlig/sqinky/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .github/ .standard.yml Appraisals gemfiles/ mise.toml benchmarks/])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "activerecord", ">= 7.0.0"
  spec.add_dependency "activesupport", ">= 7.0.0"
  spec.add_dependency "sqids", ">= 0.2.0"
  spec.add_development_dependency "appraisal"
  spec.add_development_dependency "irb"
  spec.add_development_dependency "pg"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.2"
  spec.add_development_dependency "standard", "~> 1.3"
  spec.add_development_dependency "sqlite3"
  spec.add_development_dependency "benchmark-ips"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
