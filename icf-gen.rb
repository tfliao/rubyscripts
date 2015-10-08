#! /usr/bin/ruby
require 'optparse'
require 'ostruct'

class IcfGen
	@basename = File.basename(__FILE__, ".rb")
	@version  = '1.2.0'
	@options  = NIL

	@ofile = NIL

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

	def __parse(argv)
		__parse_init

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

			opts.on("-t=t", "--target=t", "target pattern (e.g. PHYSICALDRIVE:3)") do |t|
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
					if ss.upcase == 'IDLE' then
						@options.specs << [STR_IDLE, STR_IDLE, STR_IDLE]
						next
					end

					size, rs, rw = ss.split(' ', 3)
					data = /([0-9]+)(K?)/.match(size)
					next if data == NIL
					size = data[1].to_i
					size = size * 1024 if data[2] == 'K'

					type = STR_RAND
					type = STR_SEQ if rs[0].upcase == 'S'

					io = STR_READ
					io = STR_WRITE if rw[0].upcase == 'W'

					@options.specs << [size, type, io]
				end
			end

		end
		@options.remains = parser.parse(argv)

		msg = NIL
		msg = "runtime not set" if @options.runtime == NIL
		msg = "no manager specified" if @options.managers.count == 0
		msg = "no test spec specified" if @options.specs.count == 0

		if msg != NIL
			puts msg
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
		@ofile.printf "	0\n"
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
			next if s[0] == STR_IDLE
			name = "#{__scalize(s[0])} #{s[1]} #{s[2]}"
			p_read, p_rand = 100, 100
			p_rand = 0 if s[1] == STR_SEQ
			p_read = 0 if s[2] == STR_WRITE
			conf = [s[0], 100, p_read, p_rand, 0, 1, 0, 0]
			pattern = "#{conf.join(',')}"
			specification[name] = pattern
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
				if s[0] == STR_IDLE then
					@ofile.printf "\t#{STR_IDLE}\n"
				else
					@ofile.printf "\t#{__scalize(s[0])} #{s[1]} #{s[2]}\n"
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


