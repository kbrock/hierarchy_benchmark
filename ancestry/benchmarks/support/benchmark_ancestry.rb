require 'ancestry'
require 'ancestry/version'

require_relative '../../../support/benchmark_runner'
require_relative '../../../support/helpers'

module Benchmark
  module Ancestry
    def ancestry(label = nil, version: ::Ancestry::VERSION.to_s, time:, disable_gc: true, warmup: 3, &block)
      Benchmark::Runner.run(label, version: version, time: time, disable_gc: disable_gc, warmup: warmup, &block)
    end
  end

  extend Benchmark::Ancestry
end
