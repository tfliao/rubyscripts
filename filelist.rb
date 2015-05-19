#! /usr/bin/ruby
require 'optparse'
require 'ostruct'

def parse()
	# init
	options = OpenStruct.new
	options.single = false
	options.vim = false
	options.binary = false
	options.key = ""
	options.basedirs = ["."]

	parser = OptionParser.new do |opts|
		# banner for help message
		opts.banner = "Usage: #{$0} [options] key [basedir]"
		opts.separator "  get files that contain key string"
		opts.separator ""

		# register each option
		opts.on_tail("-h", "--help", "show this help message") do
			puts opts
			exit
		end

		opts.on("-1", "--single", "show each file in single line") do |v|
			options.single = v
		end
		opts.on("-v", "--vim", "open all files by vim with tabs") do |v|
			options.vim = v
		end
		opts.on("-b", "--[no-]binary", "show binary files") do |v|
			options.binary = v
		end

	end
	args = parser.parse!
	if args.empty? then
		puts "No Key given!"
		puts parser.help()
		exit 1
	end
	options.key = args.shift
	options.basedirs = args if !args.empty?

	options
end

o = parse()


files = `grep -nr "#{o.key}" #{o.basedirs.join(' ')} | cut -d: -f1 | uniq`.split("\n")

# remove binary files
if !o.binary then
	files.delete_if { |f| f.downcase.start_with?("binary file ") }
else
	files = files.map do |f|
		if f.downcase.start_with?("binary file ") then
			f = f.split(' ').at(2)
		end
		f
	end
end

if o.vim then
	exec "vim -p #{files.join(' ')}"
end

if o.single then
	puts files
else
	puts files.join(' ')
end


