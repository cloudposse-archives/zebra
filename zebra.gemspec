# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "zebra/version"

Gem::Specification.new do |s|
  s.name        = "zebra"
  s.version     = Zebra::VERSION
  s.authors     = ["osterman"]
  s.email       = ["e@osterman.com"]
  s.homepage    = "https://github.com/osterman/zebra"
  s.summary     = %q{A Goliath Reverse HTTP Proxy Implementation Using ZMQ}
  s.description = %q{Zebra is a HTTP proxy server that uses ZMQ as the wire protocol between HTTP proxy gateway(s) and backend worker node(s). This allows for seamless load distribution to worker nodes behind a firewall.}

  s.rubyforge_project = "zebra"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_runtime_dependency "bundler"
  s.add_runtime_dependency "deep_merge", ">= 1.0.0"
  s.add_runtime_dependency "em-synchrony", ">= 1.0.0"
  s.add_runtime_dependency "em-http-request",  ">=1.0.2"
  s.add_runtime_dependency "em-zeromq", ">= 0.3.0"
  s.add_runtime_dependency "ffi-rzmq", ">= 0.9.3"
  s.add_runtime_dependency "goliath", ">= 0.9.4"
  s.add_runtime_dependency "json", ">= 1.6.5"
  s.add_runtime_dependency "preforker", ">= 0.1.1"
  s.add_runtime_dependency "uuid", ">= 2.3.5"
  s.add_runtime_dependency "yajl-ruby", ">= 1.1.0"
end
