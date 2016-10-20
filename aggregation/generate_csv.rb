#!/usr/bin/ruby

require 'json'
require 'tmpdir'

unless ARGV.length == 1 then
  puts "generate_csv.rb <input_file>"
  puts "\t<input_file> is a file full of JSON objects, specifically the output of diego_results.sh"
  exit 1
end

input_file = ARGV.shift

input = File.readlines(input_file).reject{ |line| /\{"results":\[\{\}\]\}/.match line }.reject{ |line| line == "\n" }

Dir.mktmpdir do |dir|
  Dir.chdir dir do

    input.each do |obj|
      metrics = JSON.parse(obj)['results'].first

      metrics['series'].each do |metric|

        metric_name = "#{metric['name']}"
        metric_name += "-#{metric['tags']['component']}-#{metric['tags']['request']}" unless metric['tags'].nil? || metric['tags']['component'].nil?

        metric_filename = metric_name.tr('/', '_') + ".csv"

        unless File.exists? metric_filename then
          temp_handle = File.new(metric_filename, "w")
          temp_handle.puts(metric_name + "," + metric['columns'].drop(1).join(","))
          temp_handle.close
        end

        temp_handle = File.open(metric_filename, "a")
        temp_handle.puts(metric['values'].first.join(","))
        temp_handle.close
      end
    end
  end

  File.open('metrics.csv', "w+") do |merged_file|
    Dir.glob(dir + '/*').each do |file|

      merged_file.puts ""

      File.foreach(file) do |line|
        merged_file.write(line)
      end
    end
  end
end
