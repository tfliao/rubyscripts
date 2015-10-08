#! /usr/bin/ruby
require 'optparse'
require 'ostruct'

class CliBase
	@options = NIL

	def _parse_init()
		@options = OpenStruct.new
		@options.verbose = false
		@options.list = []
		@options.value = 0
		@options.remains = []
	end

	def parse(argv)
		# init
		basename = File.basename(__FILE__, ".rb")

		_parse_init()

		parser = OptionParser.new do |opts|
			# banner for help message
			opts.banner =  "Usage: #{basename} [options] args ... "
			opts.separator "       <description of program here>"
			opts.separator ""

			# common options
			opts.on_tail("-h", "--help", "show this help message") do
				puts opts
				exit
			end
			opts.on_tail("--version", "show version") do
				puts "#{basename} 1.0.0"
				exit
			end

			# specific options
			## switch on/off
			opts.on("-v", "--[no-]verbose", "run verbosely") do |v|
				@options.verbose = v
			end
			## load value
			opts.on("-x=X", "--xvalue=X", "accept value") do |x|
				@options.value = x.to_i
			end
			## list type
			opts.on("-l x, ...", "--list x, ...", Array, "accept list") do |l|
				@options.list.concat(l)
			end
		end
		@options.remains = parser.parse(argv)

		@options
	end
	def run()
		puts parse(ARGV)
	end
end

if __FILE__ == $0 then
	CliBase.new.run
end
