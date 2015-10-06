#! /usr/bin/ruby
require 'optparse'
require 'ostruct'

STR_RAND='Random'
STR_SEQ='Sequential'

STR_READ='Read'
STR_WRITE='Write'

def parse()
	# init
	basename = File.basename(__FILE__, ".rb")

	options = OpenStruct.new
	options.file = NIL
	options.runtime = NIL
	options.managers = []
	options.workers = 1
	options.outstanding = 1
	options.thread = 1
	options.space = 0
	options.onepc = false
	options.target = "PHYSICALDRIVE:3"
	options.specs = []

	options.remains = []

	parser = OptionParser.new do |opts|
		# banner for help message
		opts.banner =  "Usage: #{basename} [options] args ... "
		opts.separator "       generate iometer config with some rules"
		opts.separator ""

		# common options
		opts.on_tail("-h", "--help", "show this help message") do
			puts opts
			exit
		end
		opts.on_tail("--version", "show version") do
			puts "#{basename} 1.1.1"
			exit
		end

		opts.on("-f=F", "--file=F", "output file") do |f|
			options.file = f
		end

		opts.on("-r=R", "--runtime=R", "runtime for test (hh:mm:ss)") do |r|
			options.runtime = r.split(':', 3).map(&:to_i)
		end

		opts.on("-m=m, ...", "--managers=m, ...", Array, "managers informations") do |m|
			m.each do |mm|
				name, ip = mm.split(':', 2)
				options.managers << [name, ip]
			end
		end

		opts.on("-w=w", "--workers=w", "number of workers") do |w|
			options.workers = w.to_i
		end

		opts.on("-o=o", "--outstanding=o", "outstanding IOs") do |o|
			options.outstanding = o.to_i
		end

		opts.on("-t=t", "--target=t", "target pattern (e.g. PHYSICALDRIVE:3)") do |t|
			options.target = t
		end

		opts.on("-S=S", "--space=S", "space of start sector") do |s|
			options.space = s.to_i
		end

		opts.on("-T=T", "--thread=T", "number of thread for each target") do |t|
			options.thread = t.to_i
		end

		opts.on("-1", "--onepc", "use only single pc, bug act as multiple") do |o|
			options.onepc = o
		end

		opts.on("-s=s,...", "--spec=s,...", Array, "Specification to test with (xK R(andom)/S(equential) R(ead)/W(rite)") do |s|
			s.each do |ss|
				size, rs, rw = ss.split(' ', 3)
				data = /([0-9]+)(K?)/.match(size)
				next if data == NIL
				size = data[1].to_i
				size = size * 1024 if data[2] == 'K'

				type = STR_RAND
				type = STR_SEQ if rs[0].upcase == 'S'

				io = STR_READ
				io = STR_WRITE if rw[0].upcase == 'W'

				options.specs << [size, type, io]
			end
		end

	end
	options.remains = parser.parse!

	msg = NIL
	msg = "runtime not set" if options.runtime == NIL
	msg = "no manager specified" if options.managers.count == 0
	msg = "no test spec specified" if options.specs.count == 0

	if msg != NIL
		puts msg
		puts parser.help()
		exit 1
	end

	options
end

def write_version(fp, option)
	fp.puts "Version 2006.07.27 "
end

def write_test_setup(fp, option)

	fp.printf "'TEST SETUP ====================================================================
'Test Description
	
'Run Time
'	hours      minutes    seconds
	%d          %d         %d
'Ramp Up Time (s)
	0
'Default Disk Workers to Spawn
	NUMBER_OF_CPUS
'Default Network Workers to Spawn
	0
'Record Results
	ALL
'Worker Cycling
'	start      step       step type
	1          1          LINEAR
'Disk Cycling
'	start      step       step type
	1          1          LINEAR
'Queue Depth Cycling
'	start      end        step       step type
	1          32         2          EXPONENTIAL
'Test Type
	NORMAL
'END test setup
", option.runtime[0], option.runtime[1], option.runtime[2]
end

def write_result_display(fp, option)
	fp.printf "'RESULTS DISPLAY ===============================================================
'Update Frequency,Update Type
	0,WHOLE_TEST
'Bar chart 1 statistic
	Total I/Os per Second
'Bar chart 2 statistic
	Total MBs per Second
'Bar chart 3 statistic
	Average I/O Response Time (ms)
'Bar chart 4 statistic
	Maximum I/O Response Time (ms)
'Bar chart 5 statistic
	%% CPU Utilization (total)
'Bar chart 6 statistic
	Total Error Count
'END results display
"
end

def _scalize(x)
	kilo = 1024
	postfix=['K', 'M', 'G', 'T', 'P']
	order=''

	0.upto(4) do |i|
		if x % kilo != 0 then
			break
		end
		x = x / kilo
		order = postfix[i]
	end

	return "#{x}#{order}"
end

def write_specification(fp, option)

specification = {}
option.specs.each do |s|
	name = "#{_scalize(s[0])} #{s[1]} #{s[2]}"
	p_read, p_rand = 100, 100
	p_rand = 0 if s[1] == STR_SEQ
	p_read = 0 if s[2] == STR_WRITE
	conf = [s[0], 100, p_read, p_rand, 0, 1, 0, 0]
	pattern = "#{conf.join(',')}"
	specification[name] = pattern
end

fp.printf "'ACCESS SPECIFICATIONS =========================================================\n"
specification.each do |n, p|
	fp.printf "'Access specification name,default assignment
	%s,NONE
'size,%% of size,%% reads,%% random,delay,burst,align,reply
	%s
", n, p
end
fp.printf "'END access specifications\n"

end

def write_worker(fp, option, manager_id)

	thread = option.thread
	space = option.space

	prefix, start_num = option.target.split(':', 2)
	start_num = start_num.to_i + manager_id * (option.workers / thread)

	1.upto(option.workers) do |id|

		start_sector = ((id - 1) % thread) * space
		target = "#{prefix}:#{start_num + (id - 1) / thread}"

		fp.printf "'Worker
	Worker %d
'Worker type
	DISK
'Default target settings for worker
'Number of outstanding IOs,test connection rate,transactions per connection
	%d,DISABLED,1
'Disk maximum size,starting sector
	0,%d
'End default target settings for worker
'Assigned access specs
", id, option.outstanding, start_sector # fix later
		option.specs.each do |s|
			fp.printf "\t#{_scalize(s[0])} #{s[1]} #{s[2]}\n"
		end
		fp.printf "'End assigned access specs
'Target assignments
'Target
	%s
'Target type
	DISK
'End target
'End target assignments
'End worker
", target
	end
end

def write_manager(fp, option)
fp.printf "'MANAGER LIST ==================================================================\n"
id = 1
option.managers.each do |m|
	name, ip = m

	fp.printf "'Manager ID, manager name
	%d,%s
'Manager network address
	%s
", id, name ,ip
	if option.onepc then
		write_worker(fp, option, id - 1)
	else
		write_worker(fp, option, 0)
	end
	fp.printf "'End manager\n"
	id = id + 1
end
fp.printf "'END manager list\n"
end


o = parse()

fp = NIL
if o.file != NIL then
	fp = File.open(o.file, "w")
end

fp = STDOUT if fp == NIL

write_version(fp, o)
write_test_setup(fp, o)
write_result_display(fp, o)
write_specification(fp, o)
write_manager(fp, o)
write_version(fp, o)

fp.close() if fp != STDOUT

