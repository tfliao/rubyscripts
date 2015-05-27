#! /usr/bin/ruby
require 'optparse'
require 'ostruct'

def parse()
	# init
	options = OpenStruct.new
	options.columns = []
	options.skip = 1
	options.limit = 99999999
	options.devices = []
	options.fields = ["file", "device", "property", "sample", "mean", "stdev", "minmax", "large-count", "small-count"]
	options.alignment = "human"
	options.files = []

	parser = OptionParser.new do |opts|
		# banner for help message
		opts.banner =  "Usage: #{$0} [options] args ... "
		opts.separator "       parse iostat result as statistic output"
		opts.separator ""

		# common options
		opts.on_tail("-h", "--help", "show this help message") do
			puts opts
			exit
		end
		opts.on_tail("--version", "show version") do
			basename = File.basename(__FILE__, ".rb")
			puts "#{basename} 1.1.1"
			exit
		end

		# specific options
		opts.on("-c=C1, ...", "--columns=C1, ...", Array, "column to parse") do |c|
			options.columns.concat(c.map(&:to_i))
		end
		opts.on("-s=S", "--skip=S", "skip first S data rows (default: 1)") do |s|
			options.skip = s.to_i
		end
		opts.on("-l=L", "--limit=L", "maximum data rows") do |l|
			options.limit = l.to_i
		end
		opts.on("-d=D1, ...", "--devices=D1, ...", Array, "device to parse") do |d|
			options.devices.concat(d)
		end
		opts.on("-f=F1, ...", "--fields=F1, ...", Array, "select result fields (#{options.fields.join(",")})") do |f|
			options.fields = f
		end
		opts.on("-a=mode", "--align=mode", "alignment mode (human, tab, space)") do |a|
			options.alignment = a
		end
	end
	options.files = parser.parse!

	options
end

def analysis(file, data, property_name)
	data.each do |key, dt|
		next if dt.data_points.empty?
		dps = dt.data_points

		max = dps.max
		min = dps.min
		mean = dps.inject(0) { |s,d| s+d } / dps.length.to_f
		variance = dps.inject(0) { |ss, d| ss + (d - mean) ** 2 } / (dps.size - 1).to_f
		stdev = Math.sqrt(variance)
		count_s = []
		count_l = []
		1.upto(4) do |i|
			count_s << dps.inject(0) { |c,d| if d < mean / (2 ** i).to_f then c + 1 else c end }
			count_l << dps.inject(0) { |c,d| if d > mean * (2 ** i).to_f then c + 1 else c end }
		end

		result = OpenStruct.new
		result.file = file
		result.device = dt.device
		result.property = property_name[dt.column]
		result.sample = dps.size
		result.mean = mean
		result.stdev = stdev
		result.minmax = [min, max]
		result.count_small = count_s
		result.count_large = count_l
		$results << result
	end
end

def param_check()
	if $options.files.empty? then
		puts "At least one file needed"
		exit
	end
	if $options.columns.empty? then
		puts "At least one column needed"
		exit
	end
	if $options.devices.empty? then
		puts "At least one device needed"
		exit
	end
end

def mkkey(device, column)
	return "#{device}_#{column}"
end

def load_data()
	$options.files.each do |f|
		data = {}
		property_name = {}
		$options.columns.each do |c|
			property_name[c] = NIL
			$options.devices.each do |d|
				key = mkkey(d,c)
				data[key] = OpenStruct.new
				data[key].device = d
				data[key].column = c
				data[key].skip_count = 0
				data[key].data_points = []
			end
		end
		if !File.file?(f) then
			puts "[#{f}] is not a file, skip it"
			next
		end
		fp = File.open(f)
		fp.each_line.with_index do |line|
			tokens = line.split(" ")
			next if tokens.empty? # empty line

			# parse header
			if tokens[0] === "Device:" then
				$options.columns.each do |c|
					next if c >= tokens.size
					property_name[c] = tokens[c]
				end
				next
			end

			if $options.devices.include?(tokens[0]) then
				$options.columns.each do |c|
					next if c >= tokens.size
					key = mkkey(tokens[0], c)
					if data[key].skip_count < $options.skip then
						data[key].skip_count += 1
					elsif data[key].data_points.size < $options.limit
						data[key].data_points << (tokens[c].to_f) if tokens[c].to_f > 0.0001
					end
				end
			end

		end
		fp.close()
		analysis(f, data, property_name)
		data.clear()
	end

end

def format_field(field, result, float_part)
	separator = ", "
	separator = "," if $options.alignment != "human"

	case field
		when "file" then return result.file
		when "device" then return result.device
		when "property" then return result.property
		when "sample" then return "#{result.sample}"
		when "mean" then return "#{result.mean.round(float_part)}"
		when "stdev" then return "#{result.stdev.round(float_part)}"
		when "minmax" then return "(#{result.minmax[0].round(float_part)}#{separator}#{result.minmax[1].round(float_part)})"
		when "large-count" then return "#{result.count_large.join(separator)}"
		when "small-count" then return "#{result.count_small.join(separator)}"
		else return "-"
	end
end

def output()
	width = Hash.new
	$options.fields.each do |f|
		width[f] = $results.inject(f.size) do |mx, rs|
			rs_w = format_field(f, rs, 2)
			[mx, rs_w.size].max
		end
	end

	header = ""
	$options.fields.each do |f|
		case $options.alignment
		when "tab"
			header << "#{f}\t"
		when "space"
			header << "#{f} "
		else # human reading
			header << ("%*s" % [ -(width[f] + 1), f] )
		end
	end
	puts header

	$results.each do |rs|
		line = ""
		$options.fields.each do |f|
			value = format_field(f, rs, 2)
			case $options.alignment
			when "tab"
				line << "#{value}\t"
			when "space"
				line << "#{value} "
			else # human reading
				line << ("%*s" % [ -(width[f] + 1), value])
			end
		end
		puts line
	end

end

$results = []
$options = parse()

param_check()

load_data()

output()

