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
      case
      when @options['--runmode']
        dispatch_runmode(@options['--runmode'])
      when @options['--name']
        run_matching_blocks!
      else
        # Try to find one in the buffer
        runmode = ob.in_buffer_settings['RUNMODE']
        dispatch_runmode(runmode)
      end
    end

    def dispatch_runmode(runmode)
      case runmode
      when 'parallel'
        run_blocks_in_parallel!
      when 'sequential'
        run_blocks_sequentially!
      when 'runlist'
        # TODO
      else # parallel by default
        run_blocks_in_parallel!
      end
    end

    def tangle!
      results = babel.tangle!
    rescue Orgmode::Babel::TangleError
      logger.error "Cannot converge because there were errors during tangle step".fg 'red'
    end

    def run_blocks_sequentially!
      @engine = OrgConverge::Engine.new(:logger => @logger, :babel => @babel)
      babel.tangle_runnable_blocks!(@run_dir)

      runlist_stack = []
      babel.ob.scripts.each do |key, script|
        runlist_stack << [key, script]
      end

      while not runlist_stack.empty?
        key, script = runlist_stack.shift

        # Decision: Only run blocks which have a name
        next unless script[:header][:name]

        display_name = script[:header][:name]
        with_running_engine do |engine|
          file = File.expand_path("#{@run_dir}/#{key}")
          cmd = "#{script[:lang]} #{file}"
          engine.register display_name, cmd, { :cwd => @root_dir, :logger => logger }
        end
      end
      logger.info "Run has completed successfully.".fg 'green'
    end

    # TODO: Too much foreman has made this running blocks in parallel the default behavior.
    #       We should actually be supporting run lists instead, but liking this experiment so far.
    def run_blocks_in_parallel!
      @engine = OrgConverge::Engine.new(:logger => @logger, :babel => @babel)
      babel.tangle_runnable_blocks!(@run_dir)
      babel.ob.scripts.each do |key, script|
        file = File.expand_path("#{@run_dir}/#{key}")
        cmd = "#{script[:lang]} #{file}"

        # Decision: Only run blocks which have a name
        next unless script[:header][:name]

        display_name = script[:header][:name]
        @engine.register display_name, cmd, { :cwd => @root_dir, :logger => logger }
      end
      logger.info "Running code blocks now! (#{babel.ob.scripts.count} runnable blocks found in total)"
      @engine.start
      logger.info "Run has completed successfully.".fg 'green'
    end

    def run_matching_blocks!
      @engine = OrgConverge::Engine.new(:logger => @logger, :babel => @babel)
      babel.tangle_runnable_blocks!(@run_dir, :filter => @options['--name'])
      scripts = babel.ob.scripts.select {|k, h| h[:header][:name] =~ Regexp.new(@options['--name']) }
      scripts.each do |key, script|
        file = File.expand_path("#{@run_dir}/#{key}")
        cmd = "#{script[:lang]} #{file}"
        display_name = script[:header][:name]
        @engine.register display_name, cmd, { :cwd => @root_dir, :logger => logger }
      end

      logger.info "Running code blocks now! (#{scripts.count} runnable blocks found in total)"
      @engine.start
      logger.info "Run has completed successfully.".fg 'green'
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
      ob.tangle.each do |file, block|
        puts "---------- #{file} --------------".fg 'green'
        puts block[:lines]
      end

      ob.scripts.each do |index, block|
        puts "---------- script: #{index} to be run with: #{block[:header][:shebang]} --------------".fg 'green'
        puts block[:lines]
      end
    end
  end
end
