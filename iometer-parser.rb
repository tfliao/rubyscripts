#! /usr/bin/ruby
require 'optparse'
require 'ostruct'

class IometerParser
	def initialize()
		@basename = File.basename(__FILE__, ".rb")
		@version  = '1.2.0'
		__parse_init
	end

	STR_IOPS='iops'
	STR_MBPS='mb/s'
	STR_RESP='resp'
	STR_ALL ='all'

	def run()
		__parse(ARGV)
		@options.fields << 'auto' if @options.fields.empty?
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
		@options.fields = []
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
			opts.on("-o=O, ...", "--order=O, ...", Array, "order of result") do |v|
				@options.order.concat(v)
			end
			opts.on("-v", "--verbose", "force show some message") do |v| @options.verbose = v end
			opts.on("-r=R", "--result=R", "available:raw, avg, ...") do |v| @options.result = v end

			opts.on("-f=F, ...", "--fields=F, ...", Array, "available: iops, MB/s, Resp, all, ...") do |v| @options.fields.concat(v) end

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

		value.each do |field, val|
			case result
			when 'avg'
				avg = val.inject(0.0) { |s, v| s + v.to_f } / val.size
				puts "%13.5f\t%s\t[%s]" % [avg, field, key]
			else # other including raw
				val.each_with_index do |v, n|
					puts "%13.5f" % v + (n==0 ? "\t%s\t[%s]" % [field, key] : "")
				end
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
				value = Hash.new
				@options.fields.each do |f|
					case f.downcase
					when STR_IOPS
						value[STR_IOPS] = tokens[6] # IOPS
					when STR_MBPS
						value[STR_MBPS] = tokens[9] # MB/s
					when STR_RESP
						value[STR_RESP] = tokens[17] # response time
					when STR_ALL
						value[STR_IOPS] = tokens[6] # IOPS
						value[STR_MBPS] = tokens[9] # MB/s
						value[STR_RESP] = tokens[17] # response time
					else
						if __maybethroughput(key)
							value[STR_MBPS] = tokens[9] # MB/s
						else
							value[STR_IOPS] = tokens[6] # IOPS
						end
					end
				end
				data[key] = Hash.new if !data.has_key?(key)
				value.each do |k,v|
					data[key][k] = Array.new if !data[key].has_key?(k)
					data[key][k] << v
				end
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


