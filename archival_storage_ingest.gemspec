# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'archival_storage_ingest/version'

Gem::Specification.new do |spec|
  spec.name = 'archival_storage_ingest'
  spec.version = ArchivalStorageIngest::VERSION
  spec.authors = %w[Shinwoo Kim Matt Connolly]
  spec.email = %w[sk274@cornell.edu mjc12@cornell.edu]

  spec.summary = 'Archival storage ingest.'
  spec.description = 'Archival storage ingest.'
  spec.homepage = 'https://github.com/cul-it/archival_storage_ingest'

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata) # rubocop:disable Style/GuardClause
    spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise 'RubyGems 2.0 or newer is required to protect against public gem pushes.'
  end

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      f.match(%r{^(test|spec|features)/})
    end
  end
  spec.required_ruby_version = '~> 3.1'
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # rubocop:disable Gemspec/DevelopmentDependencies
  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'coveralls'
  spec.add_development_dependency 'nokogiri'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'rubocop-rake'
  spec.add_development_dependency 'rubocop-rspec'
  # rubocop:enable Gemspec/DevelopmentDependencies

  spec.add_runtime_dependency 'aws-sdk'
  spec.add_runtime_dependency 'inifile'
  spec.add_runtime_dependency 'json_schemer'
  spec.add_runtime_dependency 'mail'
  spec.add_runtime_dependency 'opensearch-ruby'
  spec.add_runtime_dependency 'rubyzip'
  spec.metadata['rubygems_mfa_required'] = 'true'
end
