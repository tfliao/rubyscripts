#! /usr/bin/ruby
require 'optparse'
require 'ostruct'

class IcfGen
	def initialize()
		@basename = File.basename(__FILE__, ".rb")
		@version  = '1.3.0'
		@ofile = NIL
		__parse_init
	end

	STR_RAND='Random'
	STR_SEQ='Sequential'

	STR_READ='Read'
	STR_WRITE='Write'

	STR_IDLE='Idle'

	def run()
		__parse(ARGV)

		if @options.file != NIL then
			@ofile = File.open(@options.file, "w")
		end
		@ofile = STDOUT if @ofile == NIL

		__write_version
		__write_test_setup
		__write_result_display
		__write_specification
		__write_manager
		__write_version

		@ofile.close() if @ofile != STDOUT
	end

	private

	def __parse_init()
		@options = OpenStruct.new
		@options.file = NIL
		@options.runtime = NIL
		@options.ramptime = 0
		@options.managers = []
		@options.workers = 1
		@options.outstanding = 1
		@options.thread = 1
		@options.space = 0
		@options.onepc = false
		@options.target = "PHYSICALDRIVE:3"
		@options.specs = []
		@options.remains = []
	end

	def __param_check()
		pass = true

		msg = NIL
		if @options.runtime == NIL then
			puts "runtime not set"
			pass = false
		end
		if @options.managers.count == 0 then
			puts "no manager specified"
			pass = false
		end
		if @options.specs.count == 0 then
			puts "no test spec specified"
			pass = false
		end
		pass
	end

	def __complete_spec(spec)
		if spec['idle'] then
			spec['key'] = STR_IDLE
			return spec
		end

		return NIL if spec == NIL

		return NIL if spec['size'] == NIL
		return NIL if spec['randomness'] == NIL
		return NIL if spec['iorate'] == NIL
		spec['align'] = false if spec['align'] == NIL

		spec['idle'] = false if spec['idle'] == NIL

		key = "#{__scalize(spec['size'])} "
		key += "aligned " if spec['align']
		case spec['randomness']
		when 0
			key += "#{STR_SEQ} "
		when 100
			key += "#{STR_RAND} "
		else
			key += "#{spec['randomness']} #{STR_RAND} "
		end

		case spec['iorate']
		when 0
			key += "#{STR_WRITE}"
		when 100
			key += "#{STR_READ}"
		else
			key += "#{spec['iorate']} #{STR_READ}"
		end
		spec['key'] = key

		return spec
	end

	def __parse_spec(str)
# Idle
#
# XK
#	 [align[ed]]
#                ??%   S[equential]
#                ??%   R[andom]
#                                   ??%     W[rite]
#                                   ??%     R[ead]
##		type:       Idle / IO / error
##      size:       XK
##      aligned:    true / false
##      randomness: ??%
##      iorate:     ??%
		tokens = str.split
		token = tokens.shift
		return NIL if token == NIL

		spec = Hash.new

		if token.upcase == STR_IDLE.upcase then
			spec['idle'] = true
			return __complete_spec(spec)
		end

		percent = 100
		while token != NIL do
			if data = /^([0-9]+)([KMkm]?)$/.match(token) then
			#	puts "1. #{token}"
				size = data[1].to_i
				size = size * 1024 if data[2].upcase == 'K'
				size = size * 1024 * 1024 if data[2].upcase == 'M'
				spec['size'] = size
			elsif /^ALIGN/.match(token.upcase) then
			#	puts "2. #{token}"
				spec['align'] = true
			elsif data = /^([0-9]+)%$/.match(token) then
			#	puts "3. #{token}"
				percent = data[1].to_i
			else
			#	puts "4. #{token}"
				if /^S/.match(token.upcase) then
					spec['randomness'] = 100 - percent
				elsif /^RA/.match(token.upcase) then
					spec['randomness'] = percent
				elsif /^W/.match(token.upcase) then
					spec['iorate'] = 100 - percent
				elsif /^RE/.match(token.upcase) then
					spec['iorate'] = percent
				else
					puts "Bad pattern #{token}"
				end
				percent = 100
			end
			token = tokens.shift
		end

		return __complete_spec(spec)
	end

	def __parse(argv)
		parser = OptionParser.new do |opts|
			# banner for help message
			opts.banner =  "Usage: #{@basename} [options] args ... "
			opts.separator "       generate iometer config with some rules"
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

			opts.on("-f=F", "--file=F", "output file") do |f|
				@options.file = f
			end

			opts.on("-r=R", "--runtime=R", "runtime for test (hh:mm:ss)") do |r|
				@options.runtime = r.split(':', 3).map(&:to_i)
			end

			opts.on("-R=R", "--ramptime=R", "ramp up time (in seconds)") do |r|
				@options.ramptime = r.to_i
			end

			opts.on("-m=m, ...", "--managers=m, ...", Array, "managers informations") do |m|
				m.each do |mm|
					name, ip = mm.split(':', 2)
					@options.managers << [name, ip]
				end
			end

			opts.on("-w=w", "--workers=w", "number of workers") do |w|
				@options.workers = w.to_i
			end

			opts.on("-o=o", "--outstanding=o", "outstanding IOs") do |o|
				@options.outstanding = o.to_i
			end

			opts.on("-t=t", "--target=t", "target pattern (e.g. PHYSICALDRIVE:(3+))") do |t|
				@options.target = t
			end

			opts.on("-S=S", "--space=S", "space of start sector") do |s|
				@options.space = s.to_i
			end

			opts.on("-T=T", "--thread=T", "number of thread for each target") do |t|
				@options.thread = t.to_i
			end

			opts.on("-1", "--onepc", "use only single pc, bug act as multiple") do |o|
				@options.onepc = o
			end

			opts.on("-s=s,...", "--spec=s,...", Array, "Specification to test with (xK R(andom)/S(equential) R(ead)/W(rite)") do |s|
				s.each do |ss|
					spec = __parse_spec(ss)
					next if spec == NIL
					@options.specs << spec
				end
			end

		end
		@options.remains = parser.parse(argv)

		if !__param_check() then
			puts parser.help()
			exit 1
		end

		@options
	end

	def __write_version()
		@ofile.puts "Version 2006.07.27 "
	end

	def __write_test_setup()
		@ofile.printf "'TEST SETUP ====================================================================\n"
		@ofile.printf "'Test Description\n"
		@ofile.printf "	\n"
		@ofile.printf "'Run Time\n"
		@ofile.printf "'	hours      minutes    seconds\n"
		@ofile.printf "	%d          %d         %d\n", @options.runtime[0], @options.runtime[1], @options.runtime[2]
		@ofile.printf "'Ramp Up Time (s)\n"
		@ofile.printf "	%d\n", @options.ramptime
		@ofile.printf "'Default Disk Workers to Spawn\n"
		@ofile.printf "	NUMBER_OF_CPUS\n"
		@ofile.printf "'Default Network Workers to Spawn\n"
		@ofile.printf "	0\n"
		@ofile.printf "'Record Results\n"
		@ofile.printf "	ALL\n"
		@ofile.printf "'Worker Cycling\n"
		@ofile.printf "'	start      step       step type\n"
		@ofile.printf "	1          1          LINEAR\n"
		@ofile.printf "'Disk Cycling\n"
		@ofile.printf "'	start      step       step type\n"
		@ofile.printf "	1          1          LINEAR\n"
		@ofile.printf "'Queue Depth Cycling\n"
		@ofile.printf "'	start      end        step       step type\n"
		@ofile.printf "	1          32         2          EXPONENTIAL\n"
		@ofile.printf "'Test Type\n"
		@ofile.printf "	NORMAL\n"
		@ofile.printf "'END test setup\n"
	end

	def __write_result_display()
		@ofile.printf "'RESULTS DISPLAY ===============================================================\n"
		@ofile.printf "'Update Frequency,Update Type\n"
		@ofile.printf "	0,WHOLE_TEST\n"
		@ofile.printf "'Bar chart 1 statistic\n"
		@ofile.printf "	Total I/Os per Second\n"
		@ofile.printf "'Bar chart 2 statistic\n"
		@ofile.printf "	Total MBs per Second\n"
		@ofile.printf "'Bar chart 3 statistic\n"
		@ofile.printf "	Average I/O Response Time (ms)\n"
		@ofile.printf "'Bar chart 4 statistic\n"
		@ofile.printf "	Maximum I/O Response Time (ms)\n"
		@ofile.printf "'Bar chart 5 statistic\n"
		@ofile.printf "	%% CPU Utilization (total)\n"
		@ofile.printf "'Bar chart 6 statistic\n"
		@ofile.printf "	Total Error Count\n"
		@ofile.printf "'END results display\n"
	end

	def __scalize(x)
		kilo = 1024
		postfix=['K', 'M', 'G', 'T', 'P']
		order=''

		0.upto(4) do |i|
			break if x % kilo != 0
			x = x / kilo
			order = postfix[i]
		end

		return "#{x}#{order}"
	end

	def __write_specification()

		specification = {}
		@options.specs.each do |s|
			next if s['idle']
			align = 0
			align = s['size'] if s['align']
			conf = [s['size'], 100, s['iorate'], s['randomness'], 0, 1, align, 0]
			pattern = "#{conf.join(',')}"
			specification[s['key']] = pattern
		end

		@ofile.printf "'ACCESS SPECIFICATIONS =========================================================\n"
		specification.each do |n, p|
			@ofile.printf "'Access specification name,default assignment\n"
			@ofile.printf "	%s,NONE\n", n
			@ofile.printf "'size,%% of size,%% reads,%% random,delay,burst,align,reply\n"
			@ofile.printf "	%s\n", p
		end
		@ofile.printf "'END access specifications\n"

	end

	def __write_worker(manager_id)

		thread = @options.thread
		space = @options.space

		prefix, start_num = @options.target.split(':', 2)
		start_num = start_num.to_i + manager_id * (@options.workers / thread)

		1.upto(@options.workers) do |id|

			start_sector = ((id - 1) % thread) * space
			target = "#{prefix}:#{start_num + (id - 1) / thread}"

			@ofile.printf "'Worker\n"
			@ofile.printf "	Worker %d\n", id
			@ofile.printf "'Worker type\n"
			@ofile.printf "	DISK\n"
			@ofile.printf "'Default target settings for worker\n"
			@ofile.printf "'Number of outstanding IOs,test connection rate,transactions per connection\n"
			@ofile.printf "	%d,DISABLED,1\n", @options.outstanding
			@ofile.printf "'Disk maximum size,starting sector\n"
			@ofile.printf "	0,%d\n", start_sector
			@ofile.printf "'End default target settings for worker\n"
			@ofile.printf "'Assigned access specs\n"
			@options.specs.each do |s|
				if s['idle'] then
					@ofile.printf "\t#{STR_IDLE}\n"
				else
					@ofile.printf "\t#{s['key']}\n"
				end
			end
			@ofile.printf "'End assigned access specs\n"
			@ofile.printf "'Target assignments\n"
			@ofile.printf "'Target\n"
			@ofile.printf "	%s\n", target
			@ofile.printf "'Target type\n"
			@ofile.printf "	DISK\n"
			@ofile.printf "'End target\n"
			@ofile.printf "'End target assignments\n"
			@ofile.printf "'End worker\n"
		end
	end

	def __write_manager()
		@ofile.printf "'MANAGER LIST ==================================================================\n"
		id = 1
		@options.managers.each do |m|
			name, ip = m

			@ofile.printf "'Manager ID, manager name\n"
			@ofile.printf "	%d,%s\n", id, name
			@ofile.printf "'Manager network address\n"
			@ofile.printf "	%s\n", ip
			if @options.onepc then
				__write_worker(id - 1)
			else
				__write_worker(0)
			end
			@ofile.printf "'End manager\n"
			id = id + 1
		end
		@ofile.printf "'END manager list\n"
	end
end

if __FILE__ == $0 then
	ig = IcfGen.new
	ig.run
end


