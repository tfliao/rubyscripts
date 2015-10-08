#! /usr/bin/ruby
require 'optparse'
require 'ostruct'

class CliBase
	@basename = File.basename(__FILE__, ".rb")
	@version  = '1.0.0'
	@options  = NIL

	def run()
		puts __parse(ARGV)
	end

	private

	def __parse_init()
		@options = OpenStruct.new
		@options.verbose = false
		@options.list = []
		@options.value = 0
		@options.remains = []
	end

	def __parse(argv)
		# init

		__parse_init()

		parser = OptionParser.new do |opts|
			# banner for help message
			opts.banner =  "Usage: #{@basename} [options] args ... "
			opts.separator "       <description of program here>"
			opts.separator ""

			# common options
			opts.on_tail("-h", "--help", "show this help message") do
				puts opts
				exit
			end
			opts.on_tail("--version", "show version") do
				puts "#{@basename} #{@version}"
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
end

if __FILE__ == $0 then
	cb = CliBase.new
	cb.run
end

