#! /usr/bin/ruby
require 'optparse'
require 'ostruct'
require 'fileutils'

def parse()
	# init
	options = OpenStruct.new
	options.check_only = false
	options.verbose = false
	options.list = []
	options.install_path = '/usr/scripts'

	parser = OptionParser.new do |opts|
		# banner for help message
		opts.banner =  "Usage: #{$0} [options] scripts ... "
		opts.separator "       auto update scripts in this project"
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
		opts.on("-v", "--[no-]verbose", "run verbosely") do |v|
			options.verbose = v
		end
		opts.on("-c", "--check_only", "check version difference only") do |c|
			options.check_only = c
		end
		opts.on("-p=PATH", "--path=PATH", "set install_path (default /usr/scripts)") do |p|
			options.install_path = p
		end
	end
	options.list = parser.parse!

	options
end

def show_message(msg, always_show=false)
	puts msg if $options.verbose || always_show
end

def update(basename)
	FileUtils.mv("#{basename}.rb", "#{$options.install_path}/#{basename}")
	show_message("scripts #{basename} updated", true)
end

def command?(cmd)
	`which #{cmd}`
	$?.success?
end

def prepare_install_path(path)
	if File.exists?(path)
		if File.writable?(path) == NIL then
			puts "No permission in path [#{path}]"
			exit
		end
	else
		parent_path = File.expand_path("..", path)
		prepare_install_path(parent_path)
	end
	Dir.mkdir(path)
end


$options = parse()

# handle install path

prepare_install_path($options.install_path)


Dir.chdir("/tmp") do
	show_message("Clone from github ... ")
	trash = `git clone http://github.com/tfliao/rubyscripts 2>&1`
	if $?.to_i != 0 then
		show_message("Failed to clone from github.", true)
		exit
	end
	Dir.chdir("rubyscripts") do
		if $options.list.empty? then
			scripts = Dir.glob("*.rb")
		else
			scripts = $options.list
		end

		scripts.each do |s|
			basename = File.basename(s, ".rb")
			final_name = "#{$options.install_path}/#{basename}"

			next if basename == 'clibase'

			if ! File.exist?(final_name) then
				show_message("scripts #{basename} not exists", $options.check_only)
				next if $options.check_only
				update(basename)
				next
			end

			new_version = `./#{basename}.rb --version`
			version = `#{final_name} --version`

			if new_version != version then
				show_message("scripts #{basename} can be updated", $options.check_only)
				next if $options.check_only
				update(basename)
				next
			end

			show_message("scripts #{basename} is uptodate", true)
		end
	end
end

FileUtils.rm_r("/tmp/rubyscripts/")





