require 'bundler/setup'
require 'active_record'
require 'ancestry'
require_relative 'support/benchmark_ancestry'

db_setup script: "bm_ancestry.rb", depth: 2, count: 3

ActiveRecord::Base.establish_connection(ENV.fetch('DATABASE_URL'))
ActiveRecord::Migration.verbose = false

class User < ActiveRecord::Base ; has_ancestry ; end

root = User.roots.first
Benchmark.ancestry("has_children?", time: 5) do
  root.send(:clear_association_cache)
  root.has_children?
end
