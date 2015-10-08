#! /usr/bin/ruby
require 'optparse'
require 'ostruct'

class FileList
	@basename = File.basename(__FILE__, ".rb")
	@version  = '1.3.0'
	@options = NIL
	@files = NIL

	def run()
		__parse(ARGV)
		__get_files
		__do_operation
	end

	private
	def __parse_init()
		@options = OpenStruct.new
		@options.single = false
		@options.vim = false
		@options.binary = false
		@options.key = ""
		@options.basedirs = ["."]
		@options.nocase = false
		@options.excludes = []
	end

	def __parse(argv)
		# init
		__parse_init

		parser = OptionParser.new do |opts|
			# banner for help message
			opts.banner =  "Usage: #{@basename} [options] key [basedir]"
			opts.separator "       collect files that contain key"
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
			opts.on("-1", "--single", "show each file in single line") do |v|
				@options.single = v
			end
			opts.on("-v", "--vim", "open all files by vim with tabs") do |v|
				@options.vim = v
			end
			opts.on("-b", "--[no-]binary", "show binary files") do |v|
				@options.binary = v
			end
			opts.on("-i", "--ignore-case", "Ignore case distinctions") do |v|
				@options.nocase = v
			end
			opts.on("-e=pattern,...", "--exclude=pattern,...", Array, "exclude files with particular pattern") do |e|
				@options.excludes.concat(e)
			end

		end
		args = parser.parse(argv)
		if args.empty? then
			puts "No Key given!"
			puts parser.help()
			exit 1
		end
		@options.key = args.shift
		@options.basedirs = args if !args.empty?

		@options
	end

	def __get_files()
		nocase = ""
		nocase = "-i" if @options.nocase

		@files = `grep #{nocase} -nr "#{@options.key}" #{@options.basedirs.join(' ')} | cut -d: -f1 | uniq`.split("\n")

		# remove binary files
		if !@options.binary then
			@files.delete_if { |f| f.downcase.start_with?("binary file ") }
		else
			@files = @files.map do |f|
				if f.downcase.start_with?("binary file ") then
					f = f.split(' ').at(2)
				end
				f
			end
		end
		@options.excludes.each do |e|
			@files.delete_if { |f| /#{e}/.match(f) != NIL }
		end
	end

	def __do_operation
		if @options.vim then
			exec "vim -p #{@files.join(' ')}"
		end

		if @options.single then
			puts @files
		else
			puts @files.join(' ')
		end
	end


end

if __FILE__ == $0 then
	fl = FileList.new
	fl.run
end


