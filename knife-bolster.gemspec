# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "knife-bolster/version"

Gem::Specification.new do |s|
  s.name        = "knife-bolster"
  s.version     = Knife::Bolster::VERSION
  s.authors     = ["Ken Sheppardson"]
  s.email       = ["ken@change.org"]
  s.homepage    = ""
  s.summary     = "Provision entire Chef Server environments with a single command"
  s.description = s.summary

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  # s.add_development_dependency "rspec"
  # s.add_runtime_dependency "rest-client"end
end
