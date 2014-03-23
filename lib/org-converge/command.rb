module OrgConverge
  class Command
    attr_reader :dotorg
    attr_reader :logger
    attr_reader :ob

    def initialize(options)
      @options = options
      @dotorg  = options['<org_file>']
      @logger  = Logger.new(options['--log'] || STDOUT)
      @root_dir = options['--root-dir']
      @ob = Orgmode::Parser.new(File.read(dotorg)).babelize
    end

    def execute!
      case
      when @options['--showfiles']

        showfiles
      when @options['--tangle']
        tangle!
      else
        converge!
      end

      true
    rescue => e
      false
    end

    def converge!
      tangle!
    end

    def tangle!
      begin
        babel = Orgmode::Babel.new(ob, { :logger => logger, :root_dir => @root_dir })
        results = babel.tangle!
      rescue Orgmode::Babel::TangleError
        logger.error "Cannot converge because there were errors during tangle step".red
      end
    end

    def showfiles
      ob.tangle.each do |file, lines|
        puts "---------- #{file} --------------".green
        lines.each do |line|
          puts line
        end
      end

      ob.scripts.each_with_index do |script, index|
        puts "---------- script: #{index} --------------".green
        puts script
      end
    end
  end
end
