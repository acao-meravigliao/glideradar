# -*- encoding: utf-8 -*-
$:.push File.expand_path('../lib', __FILE__)
require 'glideradar/version'

Gem::Specification.new do |s|
  s.name        = 'glideradar'
  s.version     = Glideradar::VERSION
  s.authors     = ['Daniele Orlandi']
  s.email       = ['daniele@orlandi.com']
  s.homepage    = 'http://www.yggdra.it/'
  s.summary     = %q{Receives and publishes FLARM traffic to AMQP exchange}
  s.description = %q{Receives and publishes FLARM traffic to AMQP exchange}

  s.rubyforge_project = 'glideradar'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ['lib']

  # specify any dependencies here; for example:
  # s.add_development_dependency 'rspec'
  s.add_runtime_dependency 'tomte-core'
  s.add_runtime_dependency 'tomte-agents'
  s.add_runtime_dependency 'tomte-protocol'
  s.add_runtime_dependency 'serialport'
end
