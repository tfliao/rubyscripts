#! /usr/bin/ruby
require 'optparse'
require 'ostruct'
require 'fileutils'

def parse()
	# init
	basename = File.basename(__FILE__, ".rb")

	options = OpenStruct.new
	options.check_only = false
	options.verbose = false
	options.list = []
	options.install_path = '/usr/scripts'
	options.skip_clone = false

	parser = OptionParser.new do |opts|
		# banner for help message
		opts.banner =  "Usage: #{basename} [options] scripts ... "
		opts.separator "       auto update scripts in this project"
		opts.separator ""

		# common options
		opts.on_tail("-h", "--help", "show this help message") do
			puts opts
			exit
		end
		opts.on_tail("--version", "show version") do
			puts "#{basename} 1.2.5"
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
		opts.on("--skip-clone", "skip git clone, for develop use") do |sc|
			options.skip_clone = sc
		end
	end
	options.list = parser.parse!

	options
end

def show_message(msg, always_show=false)
	puts msg if $options.verbose || always_show
end

def update(basename)
	final_name = "#{$options.install_path}/#{basename}"
	if File.exists?(final_name) then
		if !File.writable?(final_name) then
			show_message("script [#{basename}] NOT updated, No permission", true)
			return
		end
	end
	FileUtils.mv("#{basename}.rb", final_name)
	show_message("script [#{basename}] updated", true)
end

def command?(cmd)
	`which #{cmd}`
	$?.success?
end

def prepare_install_path(path)
	if File.exists?(path)
		if !File.writable?(path) then
			puts "No permission in path [#{path}]"
			exit
		end
		return
	else
		parent_path = File.expand_path("..", path)
		prepare_install_path(parent_path)
	end
	Dir.mkdir(path)
end

def update_script(script)
	basename = File.basename(script, ".rb")
	install_name = "#{$options.install_path}/#{basename}"

	if ! File.exist?(install_name) then
		show_message("script [#{basename}] not exists", $options.check_only)
		return if $options.check_only
		update(basename)
		return
	end

	new_version = `./#{basename}.rb --version`
	version = `#{install_name} --version`

	if new_version != version then
		show_message("script [#{basename}] can be updated", $options.check_only)
		return if $options.check_only
		update(basename)
		return
	end

	show_message("script [#{basename}] is uptodate", true)
end

def remove_script(script)
	basename = File.basename(script, ".rb")
	install_name = "#{$options.install_path}/#{basename}"

	if File.exists?(install_name) then
		show_message("script [#{basename}] is deprecated")
		return if $options.check_only
		FileUtils.rm(install_name)
		show_message("script [#{basename}] is removed", $options.check_only)
	end

end

$options = parse()

# handle install path

prepare_install_path($options.install_path)


Dir.chdir("/tmp") do
	if ! $options.skip_clone then
		show_message("Clone from github ... ")
		trash = `git clone http://github.com/tfliao/tf-scripts 2>&1`
		if $?.to_i != 0 then
			show_message("Failed to clone from github.", true)
			exit
		end
	end

	Dir.chdir("tf-scripts") do
		# remove, only when update-all
		if $options.list.empty? then
			File.read("deprecated-list").split("\n").each do |s|
				remove_script(s)
			end
		end

		# check and update
		if $options.list.empty? then
			scripts = File.read("all-list").split("\n")
		else
			scripts = $options.list
		end

		scripts.each do |s| update_script(s) end
	end
end

FileUtils.rm_r("/tmp/tf-scripts/") if ! $options.skip_clone


