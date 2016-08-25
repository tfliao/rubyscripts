#! /usr/bin/ruby
require 'optparse'
require 'ostruct'
require 'scanf'

class Define

	def initialize()
		@basename = File.basename(__FILE__, ".rb")
		@version  = '1.0.1'
		__parse_init
	end

	def run()
		__parse(ARGV)
		@options.files.each do |f|
			__handlefile(f)
		end
	end

	private

	def __parse_init()
		@options = OpenStruct.new
		@options.define = ""
		@options.files = []
	end

	def __param_check()
		pass = true
		# some test here
		if @options.define == ""
			puts "No define string given"
			pass = false
		end
		if @options.files.empty?
			puts "No file given"
			pass = false
		end
		pass
	end

	def __parse(argv)
		parser = OptionParser.new do |opts|
			# banner for help message
			opts.banner =  "Usage: #{@basename} [options] file"
			opts.separator "       create define enclouse for diff file"
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


			opts.on("-d=D", "--define=D", "define string") do |d|
				@options.define = d
			end
		end
		@options.files = parser.parse(argv)

		if ! __param_check() then
			puts parser.help()
			exit 1
		end

		@options
	end

	class Segment
		def initialize(line, offset, define)
			tokens = line.scanf("@@ -%d,%d +%d,%d @@%[^\n\r]")
			@from_offset, @from_len, @to_offset, @to_len, @tag = tokens
			@define = define
			@diff_len = 0
			@adds = []
			@removes = []
			@results = []
			@add_cnt = 0
			@rem_cnt = 0
			@nor_cnt = 0
		end

		def put(line)
			isEnd = false
			case line[0]
			when "+"
				@adds << line[1..-1]
				@add_cnt += 1
			when "-"
				@removes << line[1..-1]
				@rem_cnt += 1
			else
				@nor_cnt += 1
				if !@adds.empty? and !@removes.empty?
					@diff_len = @diff_len + 3 + @removes.length
					@results << "+#ifdef #{@define}"
					@adds.each do |a| @results << "+#{a}" end
					@results << "+#else /* #{@define} */"
					@removes.each do |r| @results << " #{r}" end
					@results << "+#endif /* #{@define} */"
				elsif !@adds.empty?
					@diff_len = @diff_len + 2
					@results << "+#ifdef #{@define}"
					@adds.each do |a| @results << "+#{a}" end
					@results << "+#endif /* #{@define} */"
				elsif !@removes.empty?
					@diff_len = @diff_len + 2 + @removes.length
					@results << "+#if !define(#{@define})"
					@removes.each do |r| @results << " #{r}" end
					@results << "+#endif /* #{@define} */"
				end
				@results << line
				@adds = []
				@removes = []
			end
			return @nor_cnt + @rem_cnt == @from_len && @nor_cnt + @add_cnt == @to_len
		end
		def dumps()
			res = "@@ -%d,%d +%d,%d @@%s\n" % [@from_offset, @from_len, @to_offset, @to_len + @diff_len, @tag]
			@results.each do |l|
				res << "#{l}"
				res << "\n" if !l.end_with?("\n")
			end
			res
		end
	end


	def __handlefile(file)
		seg = NIL
		File.foreach(file) do |line|
			if line.start_with?("@@")
				seg = Segment.new(line, 0, @options.define)
				next
			end

			if seg != NIL
				isEnd = seg.put(line)
				if isEnd
					print seg.dumps()
					seg = NIL
				end
				next
			end
			puts line
		end
	end
end

if __FILE__ == $0 then
	define = Define.new
	define.run
end

