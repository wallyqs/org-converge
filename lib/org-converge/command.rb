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
      @ob    = Orgmode::Parser.new(File.read(dotorg)).babelize
      @babel = nil
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
      @logger.error e
      false
    end

    def converge!
      tangle!
      run_blocks!
      logger.info "Done".green
    end

    def tangle!
      results = babel.tangle!
    rescue Orgmode::Babel::TangleError
      logger.error "Cannot converge because there were errors during tangle step".red
    end

    # Runs the blocks sequentially
    def run_blocks!
      # TODO: Should pass the location to the tmp folder here
      run_dir = File.expand_path('run')
      babel.tangle_runnable_blocks!(run_dir)

      # Executes the scripts in order
      babel.ob.scripts.each do |key, script|
        bin = script[:lang]
        file = File.expand_path("#{run_dir}/#{key}")
        cmd = "#{bin} #{file}"
        logger.info "#+begin_run: #{cmd}" # 
        out = system(cmd)
        logger.info out
        logger.info "#+end_run"
      end
    rescue => e
      puts e
      puts e.backtrace
    end

    def babel
      @babel ||= Orgmode::Babel.new(ob, { :logger => logger, :root_dir => @root_dir })
    end

    def showfiles
      ob.tangle.each do |file, lines|
        puts "---------- #{file} --------------".green
        lines.each do |line|
          puts line
        end
      end

      ob.scripts.each do |index, block|
        puts "---------- script: #{index} to be run with: #{block[:header][:shebang]} --------------".green
        puts block[:lines]
      end
    end
  end
end
