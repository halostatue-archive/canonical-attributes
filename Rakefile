# -*- ruby -*-

require 'rubygems'
require 'hoe'
require 'pathname'

Hoe.plugin :doofus
Hoe.plugin :gemspec2
Hoe.plugin :git
Hoe.plugin :minitest
Hoe.plugin :rubygems
Hoe.plugin :travis

config = Pathname('~/.gem/geminabox').expand_path
if config.exist?
  geminabox = YAML.load(config.read)[:host]
end

if geminabox
  Hoe.plugin :geminabox
else
  raise "'geminabox' is not configured. Put a ':host' key in '~/.gem/geminabox'."
end

Hoe.spec 'canonical-attributes' do
  developer('Austin Ziegler', 'halostatue@gmail.com')

  self.geminabox_server = geminabox

  self.history_file = 'History.rdoc'
  self.readme_file = 'README.rdoc'
  self.extra_rdoc_files = FileList['*.rdoc'].to_a

  license 'MIT'

  self.extra_deps << ['activesupport', '>= 3.2', '< 5.2']

  self.extra_dev_deps << ['active_attr', '~> 0.8']
  self.extra_dev_deps << ['hoe-doofus', '~> 1.0']
  self.extra_dev_deps << ['hoe-gemspec2', '~> 1.1']
  self.extra_dev_deps << ['hoe-git', '~> 1.5']
  self.extra_dev_deps << ['hoe-rubygems', '~> 1.0']
  self.extra_dev_deps << ['hoe-travis', '~> 1.2']
  self.extra_dev_deps << ['minitest', '~> 5.4']
  self.extra_dev_deps << ['minitest-moar', '~> 0.0']
  self.extra_dev_deps << ['rake', '~> 10.0']

  self.extra_dev_deps << ['simplecov', '~> 0.7']
end

namespace :test do
  task :coverage do
    spec.test_prelude = [
      'require "simplecov"',
      'SimpleCov.start("test_frameworks") { command_name "Minitest" }',
      'gem "minitest"'
    ].join('; ')
    Rake::Task['test'].execute
  end
end

# vim: syntax=ruby
