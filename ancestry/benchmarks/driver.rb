#
# Ancestry Benchmark driver
#
require 'bundler/setup'
require 'net/http'
require 'json'
require 'pathname'
require 'optparse'
require 'digest'

#RAW_URL = 'https://raw.githubusercontent.com/ruby-bench/ruby-bench-suite/master/rails/benchmarks/'
RAW_URL = 'https://raw.githubusercontent.com/kbrock/hierarchy_benchmark/master/ancestry/benchmarks/'

# for the benchmark scripts
ENV["DATABASE_URL"] ||="postgres://localhost/ancestry_benchmark_development"
# for saving results
ENV["API_URL"]      ||= 'localhost:3000'
ENV["API_NAME"]     ||= 'development'
ENV["API_PASSWORD"] ||= '12345'

class BenchmarkDriver
  def self.benchmark(options)
    self.new(options).run
  end

  def initialize(options)
    @repeat_count = options[:repeat_count]
    @pattern = options[:pattern]
    @debug = options[:debug] || false
    @verbose = options[:verbose] || false
  end

  def run
    print "#{files.count}: " if @verbose
    files.each do |path|
      run_single(path, database: 'psql', debug: @debug)
    end
    puts if @verbose
  end

  private

  def generate_request
    request = Net::HTTP::Post.new('/benchmark_runs')
    request.basic_auth(ENV["API_NAME"], ENV["API_PASSWORD"])
    request
  end

  def default_form_data(output, path, database)
    data = {
      'benchmark_type[category]'   => output["label"],
      'benchmark_type[script_url]' => "#{RAW_URL}#{Pathname.new(path).basename}",
      'benchmark_type[digest]'     => generate_digest(path, database),
      'benchmark_run[environment]' => "#{`ruby -v`}",
      'repo'                       => 'ancestry',
      'organization'               => 'ancestry',
    }

    if(ENV['COMMIT_HASH'])
      data['commit_hash'] = ENV['COMMIT_HASH']
    elsif(ENV['VERSION'])
      data['version'] = ENV['VERSION']
    elsif(output["version"])
      data['version'] = output["version"]
    end

    data
  end

  def submit_request(form_data, results)
    request = generate_request
    request.set_form_data(form_data.merge(results))
    ret = endpoint.request(request)
    success = (ret.code.to_i / 100 == 2)
    unless success
      puts "#{ret.code} :: #{ret.message}"
      puts ret.body if ret.read_body
    end
    success
  end

  def files
    Dir["#{File.expand_path(File.dirname(__FILE__))}/bm_*"].select do |path|
      @pattern.empty? || /#{@pattern.join('|')}/ =~ File.basename(path)
    end
  end

  def run_single(path, connection: nil, database: nil, debug: false)
    script = "RAILS_ENV=production ruby #{path}"

    puts "==> #{path}" if debug
    output = measure(script)
    if !output
      puts "Error in #{path}"
      return
    end

    if debug
      puts JSON.pretty_generate(output)
      return
    end

    form_data = default_form_data(output, path, database)

    submit_request(form_data, {
      "benchmark_run[result][iterations_per_second]" => output["iterations_per_second"].round(3),
      #iterations_per_second_standard_deviation
      'benchmark_result_type[name]' => 'Number of iterations per second',
      'benchmark_result_type[unit]' => 'Iterations per second'
    }) or return

    submit_request(form_data, {
      "benchmark_run[result][total_allocated_objects_per_iteration]" => output["total_allocated_objects_per_iteration"],
      'benchmark_result_type[name]' => 'Allocated objects',
      'benchmark_result_type[unit]' => 'Objects'
    }) or return

    submit_request(form_data, {
      "benchmark_run[result][query_count_per_iteration]" => output["query_count_per_iteration"],
      'benchmark_result_type[name]' => 'Queries per iteration',
      'benchmark_result_type[unit]' => 'Queries'
    }) or return

    submit_request(form_data, {
      "benchmark_run[result][instantiation_per_iteration]" => output["instantiation_per_iteration"],
      'benchmark_result_type[name]' => 'Instantiated objects',
      'benchmark_result_type[unit]' => 'Objects'
    }) or return

    print "." if @verbose
  end

  def endpoint
    url, port = (ENV["API_URL"] || 'rubybench.org').split(":")
    port ||= 443
    http = Net::HTTP.new(url, port)
    http.use_ssl = true if port == 443 || port == 8443
    http
  end

  def generate_digest(path, database)
    string = "#{File.read(path)}#{`ruby -v`}"

    case database
    when 'psql'
      string = "#{string}#{ENV['POSTGRES_ENV_PG_VERSION']}"
    when 'mysql'
      string = "#{string}#{ENV['MYSQL_ENV_MYSQL_VERSION']}"
    end

    Digest::SHA2.hexdigest(string)
  end

  def measure(script)
    begin
      results = []

      @repeat_count.times do
        result = JSON.parse(`#{script}`)
        results << result
      end

      results.sort_by do |result|
        result['iterations_per_second']
      end.last
    rescue JSON::ParserError
      puts "error" if @debug || @verbose
      # Do nothing
    end
  end
end

options = {
  repeat_count: 1,
  pattern: []
}

OptionParser.new do |opts|
  opts.banner = "Usage: ruby driver.rb [options]"

  opts.on("-v", "--verbose", "Give progress status") do
    options[:verbose] = true
  end

  opts.on("-d", "--debug", "Run benchmark printing results to stdout") do
    options[:debug] = true
  end

  opts.on("-r", "--repeat-count [NUM]", "Run benchmarks [NUM] times taking the best result") do |value|
    options[:repeat_count] = value.to_i
  end

  opts.on("-p", "--pattern <PATTERN1,PATTERN2,PATTERN3>", "Benchmark name pattern") do |value|
    options[:pattern] = value.split(',')
  end
end.parse!(ARGV)

BenchmarkDriver.benchmark(options)
