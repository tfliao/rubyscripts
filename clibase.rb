#! /usr/bin/ruby
require 'optparse'
require 'ostruct'

def parse()
	# init
	options = OpenStruct.new
	options.verbose = false
	options.list = []
	options.value = 0
	options.remains = []

	parser = OptionParser.new do |opts|
		# banner for help message
		opts.banner =  "Usage: #{$0} [options] args ... "
		opts.separator "       <description of program here>"
		opts.separator ""

		# register each option
		opts.on_tail("-h", "--help", "show this help message") do
			puts opts
			exit
		end

		## switch on/off
		opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
			options.verbose = v
		end
		## load value
		opts.on("-x=X", "--xvalue=X", "accept value") do |x|
			options.value = x.to_i
		end
		## list type
		opts.on("-l x, ...", "--list x, ...", Array, "accept list") do |l|
			options.list.concat(l)
		end
	end
	options.remains = parser.parse!

	options
end

parse()

