require 'bundler/setup'
require 'active_record'
require 'ancestry'
require_relative 'support/benchmark_ancestry'

db_setup script: "bm_ancestry.rb", depth: 4, count: 6

ActiveRecord::Base.establish_connection(ENV.fetch('DATABASE_URL'))
ActiveRecord::Migration.verbose = false

class User < ActiveRecord::Base ; has_ancestry ; end

obj = User.last
root = User.roots.first
Benchmark.ancestry("ancestor_of?", time: 5) do
  root.send(:clear_association_cache)
  obj.send(:clear_association_cache)
  root.ancestor_of?(obj)
end
