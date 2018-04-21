require 'benchmark/ips'
require 'json'

# https://github.com/ruby-bench/ruby-bench-suite/blob/master/support/benchmark_runner.rb
module Benchmark
  # Derived from code found in http://stackoverflow.com/questions/5490411/counting-the-number-of-queries-performed
  class QueryCounter
    def self.count(&block)
      new.count(&block)
    end

    IGNORED_STATEMENTS = %w(CACHE SCHEMA)
    IGNORED_QUERIES    = /^(?:ROLLBACK|BEGIN|COMMIT|SAVEPOINT|RELEASE)/

    # thinking that sql_count is the only useful one here
    # would be nice to output explains for queries - to know whether it used indexes
    def callback(_name, _start, _finish, _id, payload)
      if payload[:sql]
        if IGNORED_STATEMENTS.include?(payload[:name]) || IGNORED_QUERIES.match(payload[:sql])
          @instances[:ignored_count] += 1
        else
          #name = payload[:name] ? payload[:name].split(" ").first : "unknown"
          #tgt = @instances[name] ||= {sql_count: 0, instance_count: 0} #, queries: []}
          #tgt[:sql_count] += 1
          ## tgt[:queries] << tgt[:sql] #payload[:binds]
          # payload[:statement_name],
          @instances[:sql_count] += 1
        end
      else
        # name = payload[:class_name]
        # tgt = @instances[name] ||= {sql_count: 0, instance_count: 0} #, queries: []}
        # tgt[:instance_count] += payload[:record_count]
        @instances[:instance_count] += payload[:record_count]
      end
    end

    def callback_proc
      lambda(&method(:callback))
    end

    def count(&block)
      @instances = {sql_count: 0, instance_count: 0}
      ActiveSupport::Notifications.subscribed(callback_proc, /active_record/, &block)
      @instances
    end
  end

  module Runner
    def self.run(label=nil, version:, time:, disable_gc:, warmup:, &block)
      unless block_given?
        raise ArgumentError.new, "You must pass block to run"
      end

      GC.disable if disable_gc

      ips_result = compute_ips(time, warmup, label, &block)
      objects_result = compute_objects(&block)
      counters = QueryCounter.count(&block)

      print_output(ips_result, objects_result, counters, label, version)
    end

    def self.compute_ips(time, warmup, label, &block)
      report = Benchmark.ips(time, warmup, true) do |x|
        x.report(label) { yield }
      end

      report.entries.first
    end

    def self.compute_objects(&block)
      if block_given?
        key =
          if RUBY_VERSION < '2.2'
            :total_allocated_object
          else
            :total_allocated_objects
          end

        before = GC.stat[key]
        yield
        after = GC.stat[key]
        after - before
      end
    end

    # NOTE:  ips_result.stddev_percentage changed names
    def self.print_output(ips_result, objects_result, counters, label, version)
      output = {
        label: label,
        version: version,
        iterations_per_second: ips_result.ips,
        iterations_per_second_standard_deviation: ips_result.error_percentage,
        total_allocated_objects_per_iteration: objects_result,
        query_count_per_iteration: counters[:sql_count],
        instantiation_per_iteration: counters[:instance_count]
      }
      puts JSON.pretty_generate(output)
      #puts output.to_json
    end
  end
end
