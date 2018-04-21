
# STRING_COLUMNS_COUNT = 25

# def db_adapter
#   ENV['DATABASE_URL'].split(":")[0]
# end

def db_setup(script:, depth:, count:)
  # run from benchmarks
  params="DATABASE_URL=#{ENV.fetch("DATABASE_URL")}"
  params="#{params} COUNT=#{count}" if count
  params="#{params} DEPTH=#{depth}" if depth

  Dir.chdir("#{__dir__}/setup") do
    #BUNDLE_GEMFILE=Gemfile 
    puts `#{params} ruby #{script}`
  end
end
