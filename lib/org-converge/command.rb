module OrgConverge
  class Command
    attr_reader :dotorg
    attr_reader :logger
    attr_reader :ob
    attr_reader :engine

    def initialize(options)
      @options   = options
      @dotorg    = options['<org_file>']
      @root_dir  = options['--root-dir']
      @run_dir   = if @root_dir
                     File.expand_path(File.join(@root_dir, 'run'))
                   else
                     File.expand_path('run')
                   end
      # The results dir will have a timestamp to avoid having to refresh all the time
      results_dirname = "results_#{Time.now.strftime("%Y%m%d%H%M%S")}"
      @results_dir = if @root_dir
                       File.expand_path(File.join(@root_dir, results_dirname))
                     else
                       File.expand_path(results_dirname)
                     end
      @ob    = Orgmode::Parser.new(File.read(dotorg)).babelize
      @babel = nil
      @logger  = Logger.new(options['--log'] || STDOUT)
      logger.formatter = proc do |severity, datetime, progname, msg| 
        "[#{datetime.strftime('%Y-%m-%dT%H:%M:%S %z')}] #{msg}\n"
      end
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
      runmode = @options['--runmode'] || ob.in_buffer_settings['RUNMODE']
      case
      when @options['--name']
        if runmode == 'sequentially'
          run_matching_blocks_sequentially!
        else
          run_matching_blocks!
        end
      else
        dispatch_runmode(runmode)
      end
    end

    def dispatch_runmode(runmode)
      case runmode
      when 'parallel'
        run_blocks_in_parallel!
      when 'sequential'
        run_blocks_sequentially!
      when 'chained', 'chain', 'tasks'
        run_blocks_chain!
      when 'spec'
        run_against_blocks_results!
      else # parallel by default
        run_blocks_in_parallel!
      end
    end

    def tangle!
      results = babel.tangle!
    rescue Orgmode::Babel::TangleError
      logger.error "Cannot converge because there were errors during tangle step".fg 'red'
    end

    def run_blocks_chain!
      # Chain the blocks by defining them as Rake::Tasks dynamically
      tasks = { }

      babel.tangle_runnable_blocks!(@run_dir)
      babel.ob.scripts.each do |key, script|
        task_name = script[:header][:name]
        next unless task_name

        task = Rake::Task.define_task task_name do
          with_running_engine do |engine|
            file = File.expand_path("#{@run_dir}/#{key}")
            cmd = "#{script[:lang]} #{file}"
            engine.register task_name, cmd, { :cwd => @root_dir, :logger => logger }
          end
        end
        tasks[task_name] = { 
          :task => task,
          :script => script
        }
      end

      # Now onto define the prerequisites and actions
      tasks.each_pair do |task_name, task_definition|
        prerequisite_task = task_definition[:script][:header][:after]
        if prerequisite_task and tasks[prerequisite_task]
          task_definition[:task].prerequisites << tasks[prerequisite_task][:task]
        end

        postrequisite_task = task_definition[:script][:header][:before]
        if postrequisite_task and tasks[postrequisite_task]
          tasks[postrequisite_task][:task].prerequisites << task_definition[:task]
        end
      end

      # The task that marks the run as done needs to be defined explicitly
      # otherwise a block named default will tried to be run
      final_task = babel.ob.in_buffer_settings['FINAL_TASK'] || 'default'

      if tasks[final_task]
        logger.info "Running final task: #{tasks[final_task][:task]}"
        tasks[final_task][:task].invoke
      else
        logger.error "Could not find a final task to run!"
      end
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

    def run_matching_blocks_sequentially!
      babel.tangle_runnable_blocks!(@run_dir)

      runlist_stack = []
      scripts = babel.ob.scripts.select {|k, h| h[:header][:name] =~ Regexp.new(@options['--name']) }
      scripts.each do |key, script|
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

    def run_against_blocks_results!
      babel.tangle_runnable_blocks!(@run_dir)

      runlist_stack = []
      scripts = if @options['--name']
                  babel.ob.scripts.select {|k, h| h[:header][:name] =~ Regexp.new(@options['--name']) }
                else
                  babel.ob.scripts
                end
      scripts.each { |key, script| runlist_stack << [key, script] }

      FileUtils.mkdir_p(@results_dir)
      while not runlist_stack.empty?
        key, script = runlist_stack.shift

        # Decision: Only run blocks which have a name
        next unless script[:header][:name]

        display_name = script[:header][:name]
        with_running_engine(:runmode => 'spec', :results_dir => @results_dir) \
        do |engine|
          script_file  = File.expand_path("#{@run_dir}/#{key}")
          results_file = File.expand_path("#{@results_dir}/#{key}")
          cmd = "#{script[:lang]} #{script_file}"
          engine.register display_name, cmd, { 
            :cwd     => @root_dir, 
            :logger  => logger,
            :results => results_file
          }
        end

        # After the run is done, we match agains the results block
      end
      logger.info "Run has completed successfully.".fg 'green'
    end

    def with_running_engine(opts={})
      default_options = { :logger => @logger, :babel => @babel }
      options = default_options.merge!(opts)
      engine = OrgConverge::Engine.new(options)
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
