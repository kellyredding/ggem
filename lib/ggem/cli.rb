require 'ggem'
require 'ggem/version'

module GGem

  class CLI

    def self.run(*args)
      self.new.run(*args)
    end

    def initialize
      @cli = CLIRB.new do
        option 'debug', 'run in debug mode'
      end
    end

    def run(*args)
      begin
        # parse manually in the case that parsing fails before the debug arg
        debug_mode ||= args.include?('-d') || args.include?('--debug')
        @cli.parse!(args)
        raise CLIRB::Error, "please provide a gem name" if @cli.args.size < 1

        path = GGem::Gem.new(Dir.pwd, *args).save!.path
        puts "created gem and initialized git repo in #{path}"
      rescue CLIRB::HelpExit
        puts help
      rescue CLIRB::VersionExit
        puts GGem::VERSION
      rescue CLIRB::Error => exception
        puts "#{exception.message}\n\n"
        puts  debug_mode ? exception.backtrace.join("\n") : help
        exit(1)
      rescue Exception => exception
        puts "#{exception.class}: #{exception.message}"
        puts exception.backtrace.join("\n") if debug_mode
        exit(1)
      end
      exit(0)
    end

    def help
      "Usage: ggem GEM-NAME\n\n"\
      "Options:"\
      "#{@cli}"
    end

  end

  class CLIRB  # Version 1.0.0, https://github.com/redding/cli.rb
    Error    = Class.new(RuntimeError);
    HelpExit = Class.new(RuntimeError); VersionExit = Class.new(RuntimeError)
    attr_reader :argv, :args, :opts, :data

    def initialize(&block)
      @options = []; instance_eval(&block) if block
      require 'optparse'
      @data, @args, @opts = [], [], {}; @parser = OptionParser.new do |p|
        p.banner = ''; @options.each do |o|
          @opts[o.name] = o.value; p.on(*o.parser_args){ |v| @opts[o.name] = v }
        end
        p.on_tail('--version', ''){ |v| raise VersionExit, v.to_s }
        p.on_tail('--help',    ''){ |v| raise HelpExit,    v.to_s }
      end
    end

    def option(*args); @options << Option.new(*args); end
    def parse!(argv)
      @args = (argv || []).dup.tap do |args_list|
        begin; @parser.parse!(args_list)
        rescue OptionParser::ParseError => err; raise Error, err.message; end
      end; @data = @args + [@opts]
    end
    def to_s; @parser.to_s; end
    def inspect
      "#<#{self.class}:#{'0x0%x' % (object_id << 1)} @data=#{@data.inspect}>"
    end

    class Option
      attr_reader :name, :opt_name, :desc, :abbrev, :value, :klass, :parser_args

      def initialize(name, *args)
        settings, @desc = args.last.kind_of?(::Hash) ? args.pop : {}, args.pop || ''
        @name, @opt_name, @abbrev = parse_name_values(name, settings[:abbrev])
        @value, @klass = gvalinfo(settings[:value])
        @parser_args = if [TrueClass, FalseClass, NilClass].include?(@klass)
          ["-#{@abbrev}", "--[no-]#{@opt_name}", @desc]
        else
          ["-#{@abbrev}", "--#{@opt_name} #{@opt_name.upcase}", @klass, @desc]
        end
      end

      private

      def parse_name_values(name, custom_abbrev)
        [ (processed_name = name.to_s.strip.downcase), processed_name.gsub('_', '-'),
          custom_abbrev || processed_name.gsub(/[^a-z]/, '').chars.first || 'a'
        ]
      end
      def gvalinfo(v); v.kind_of?(Class) ? [nil,gklass(v)] : [v,gklass(v.class)]; end
      def gklass(k); k == Fixnum ? Integer : k; end
    end
  end

end
