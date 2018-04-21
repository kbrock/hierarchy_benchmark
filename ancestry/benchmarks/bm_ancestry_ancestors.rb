require 'bundler/setup'
require 'active_record'
require 'ancestry'
require_relative 'support/benchmark_ancestry'

db_setup script: "bm_ancestry.rb", depth: 10, count: 1

ActiveRecord::Base.establish_connection(ENV.fetch('DATABASE_URL'))
ActiveRecord::Migration.verbose = false

class User < ActiveRecord::Base ; has_ancestry ; end

obj = User.last
Benchmark.ancestry("ancestors", time: 5) do
  obj.send(:clear_association_cache)
  obj.ancestors.to_a
end
