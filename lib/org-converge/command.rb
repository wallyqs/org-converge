module OrgConverge
  class Command
    attr_reader :dotorg
    attr_reader :logger
    attr_reader :ob
    attr_reader :engine

    def initialize(options)
      @options = options
      @dotorg  = options['<org_file>']
      @logger  = Logger.new(options['--log'] || STDOUT)
      @root_dir = options['--root-dir']
      @run_dir  = if @root_dir
                    File.expand_path(File.join(@root_dir, 'run'))
                  else
                    File.expand_path('run')
                  end
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
      case @options['--runmode']
      when 'parallel'
        run_blocks_in_parallel!
      when 'sequential'
        run_blocks_sequentially!
      when 'runlist'
        # TODO
      else
        run_blocks_in_parallel!
      end
    end

    def tangle!
      results = babel.tangle!
    rescue Orgmode::Babel::TangleError
      logger.error "Cannot converge because there were errors during tangle step".red
    end

    def run_blocks_sequentially!
      @engine = OrgConverge::Engine.new(:logger => @logger, :babel => @babel)
      babel.tangle_runnable_blocks!(@run_dir)

      runlist_stack = []
      babel.ob.scripts.each do |key, script|
        runlist_stack << [key, script]
      end

      begin
        key, script = runlist_stack.shift
        with_running_engine do |engine|
          file = File.expand_path("#{@run_dir}/#{key}")
          cmd = "#{script[:lang]} #{file}"
          engine.register script[:lang], cmd, { :cwd => @root_dir, :logger => logger }
        end
      end while not runlist_stack.empty?
      logger.info "Run has completed successfully.".green
    end

    # TODO: Too much foreman has made this running blocks in parallel the default behavior.
    #       We should actually be supporting run lists instead, but liking this experiment so far.
    def run_blocks_in_parallel!
      @engine = OrgConverge::Engine.new(:logger => @logger, :babel => @babel)
      babel.tangle_runnable_blocks!(@run_dir)
      babel.ob.scripts.each do |key, script|
        file = File.expand_path("#{@run_dir}/#{key}")
        cmd = "#{script[:lang]} #{file}"
        @engine.register script[:lang], cmd, { :cwd => @root_dir, :logger => logger }
      end
      logger.info "Running code blocks now! (#{babel.ob.scripts.count} runnable blocks found in total)"
      @engine.start
      logger.info "Run has completed successfully.".green
    end

    def with_running_engine
      engine = OrgConverge::Engine.new(:logger => @logger, :babel => @babel)
      yield engine
      engine.start
    end

    def babel
      @babel ||= Orgmode::Babel.new(ob, { :logger => @logger, :root_dir => @root_dir })
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
