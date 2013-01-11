# -*- encoding : utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "look_up_table/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "look_up_table"
  s.version     = LookUpTable::VERSION
  s.authors     = ["Patrick Helm"]
  s.email       = ["ph@werbeboten.de", "deradon87@gmail.com"]
  s.homepage    = "http://www.deckel-gesucht.de"
  s.summary     = "A simple LookUpTable to cache large (!) and static(!) data"
  s.description = "A simple LookUpTable to cache large (!) and static(!) data"

  s.files = Dir["{lib}/**/*"] + ["MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails", "> 3.1"

  #s.add_development_dependency "sqlite3"
  s.add_development_dependency "pg"
  s.add_development_dependency "memcache-client"
end

