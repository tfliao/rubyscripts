#! /usr/bin/ruby
require 'optparse'
require 'ostruct'

class IometerParser
	def initialize()
		@basename = File.basename(__FILE__, ".rb")
		@version  = '1.1.1'
		__parse_init
	end

	def run()
		__parse(ARGV)
		if @options.files.empty?
			__parsefile(STDIN, NIL)
		else
			@options.files.each do |f|
				if !File.file?(f) then
					puts "[#{f}] is not a file, skip it"
					next
				end
				fp = File.open(f)
				__parsefile(fp, f)
				fp.close()
			end
		end
	end

	private

	def __parse_init()
		@options = OpenStruct.new
		@options.order = []
		@options.verbose = false
		@options.result = 'raw'
		@options.field = 'auto'
	end

	def __parse(argv)
		parser = OptionParser.new do |opts|
			opts.banner =  "Usage: #{@basename} [options] files ..."
			opts.separator "       parser to parse iometer result csv files to a copy friendly format"
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
			opts.on("-o=O1, ...", "--order=O1, ...", Array, "order of result") do |v|
				@options.order.concat(v)
			end
			opts.on("-v", "--verbose", "force show some message") do |v| @options.verbose = v end
			opts.on("-r=R", "--result=R", "available:raw, avg, ...") do |v| @options.result = v end

			opts.on("-f=F", "--field=F", "available: iops, MB/s, ...") do |v| @options.field = v end

		end
		@options.files = parser.parse(argv)
		@options
	end

	def __show(key, value)
		result = @options.result

		if value == NIL
			puts "Key: " + key + ", Value is NIL" if @options.verbose
			return
		end

		case result
		when 'avg'
			avg = value.inject(0.0) { |s, v| s + v.to_f } / value.size
			puts "%.4f" % avg + "\t" + key
		else # other including raw
			value.each_with_index do |v, n|
				puts v + (n==0 ? "\t[" + key + "]" : "")
			end
		end
	end

	def __maybethroughput(key)
		return true if key.index('throughput') != NIL
		return true if key.index('32K') != NIL
		return true if key.index('64K') != NIL
		return true if key.index('32768') != NIL
		return true if key.index('65536') != NIL
		return false
	end

	def __parsefile(fp, name)
		puts "File: #{name}" if name != NIL
		data = Hash.new

		fp.each do |line|
			tokens = line.split(',')
			if tokens[0] == 'ALL'
				key = tokens[2]
				case @options.field.downcase
				when 'iops'
					value = token [6] # IOPS
				when 'mb/s'
					value = tokens[9] # MB/s
				else
					value = tokens[6] # IOPS
					if __maybethroughput(key)
						value = tokens[9] # MB/s
					end
				end
				data[key] = Array.new if !data.has_key?(key)
				data[key] << value
			end
		end

		if !@options.order.empty?
			@options.order.each do |o|
				__show(o, data[o])
			end
		else
			data.each do |key, value|
				__show(key, value)
			end
		end
		puts ""
	end

end

if __FILE__ == $0 then
	ip = IometerParser.new
	ip.run
end


