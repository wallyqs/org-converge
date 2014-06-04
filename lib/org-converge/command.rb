module OrgConverge
  class Command
    attr_reader :dotorg
    attr_reader :logger
    attr_reader :ob
    attr_reader :engine
    attr_reader :runmode

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

      # Keep track of the exit status from the process for idempotency checks
      @procs_exit_status = Hash.new { |h,k| h[k] = { } }
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
      @logger.error e.backtrace.join("\n")
      false
    end

    def converge!
      tangle!
      @runmode = @options['--runmode'] || ob.in_buffer_settings['RUNMODE']
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
      when 'sequential', 'idempotent'
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
            bin = determine_lang_bin(script)
            cmd = "#{bin} #{file}"
            run_procs(script, cmd, engine)
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
        exit_status_list = with_running_engine(:runmode => @runmode) \
        do |engine|
          file = File.expand_path("#{@run_dir}/#{key}")
          bin = determine_lang_bin(script)
          cmd = "#{bin} #{file}"
          run_procs(script, cmd, engine)
        end
        @procs_exit_status.merge!(exit_status_list)
      end
      logger.info "Run has completed successfully.".fg 'green'
    end

    def run_blocks_in_parallel!
      @engine = OrgConverge::Engine.new(:logger => @logger, :babel => @babel)
      babel.tangle_runnable_blocks!(@run_dir)
      babel.ob.scripts.each do |key, script|
        # Decision: Only run blocks which have a name
        next unless script[:header][:name]

        file = File.expand_path("#{@run_dir}/#{key}")
        bin = determine_lang_bin(script)
        cmd = "#{bin} #{file}"
        run_procs(script, cmd)
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
        bin = determine_lang_bin(script)
        cmd = "#{bin} #{file}"
        run_procs(script, cmd)
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
          bin = determine_lang_bin(script)
          cmd = "#{bin} #{file}"
          run_procs(script, cmd, engine)
        end
      end
      logger.info "Run has completed successfully.".fg 'green'
    end

    def run_against_blocks_results!
      require 'diff/lcs'
      require 'diff/lcs/hunk'

      succeeded = []
      failed    = []

      logger.info "Runmode: spec"
      runlist_stack = []
      scripts = if @options['--name']
                  babel.ob.scripts.select {|k, h| h[:header][:name] =~ Regexp.new(@options['--name']) }
                else
                  babel.ob.scripts
                end
      scripts.each { |key, script| runlist_stack << [key, script] }

      babel.tangle_runnable_blocks!(@run_dir)
      FileUtils.mkdir_p(@results_dir)

      while not runlist_stack.empty?
        key, script = runlist_stack.shift

        # Decision: Only run blocks which have a name
        next unless script[:header][:name]

        display_name = script[:header][:name]
        script_file  = File.expand_path("#{@run_dir}/#{key}")
        results_file = File.expand_path("#{@results_dir}/#{key}")
        bin = determine_lang_bin(script)
        cmd = "#{bin} #{script_file}"

        with_running_engine(:runmode => 'spec', :results_dir => @results_dir) \
        do |engine|
          engine.register display_name, cmd, { 
            :cwd     => @root_dir, 
            :logger  => logger,
            :results => results_file
          }
        end

        if scripts[:results]
          print "Checking results from '#{display_name.fg 'yellow'}' code block:\t"
          expected_lines = script[:results].split("\n").map! {|e| e.chomp }
          actual_lines   = File.open(results_file).read.split("\n").map! {|e| e.chomp }

          output_diff = diff(expected_lines, actual_lines)
          if output_diff.empty?
            puts "OK".fg 'green'
            succeeded << display_name
          else
            puts "DIFF".fg 'red'
            puts output_diff.fg 'red'
            failed << display_name
          end
        end
      end

      if failed.count > 0
        puts ''
        puts 'Failed code blocks:'.fg 'red'
        failed.each do |name|
          puts "  - #{name.fg 'yellow'}"
        end
        puts ''
      end

      puts "#{succeeded.count + failed.count} examples, #{failed.count} failures".fg 'green'
      exit 1 if failed.count > 0
    end

    private
    def diff(expected_lines, actual_lines)
      output = ""
      file_length_difference = 0

      diffs = Diff::LCS.diff(expected_lines, actual_lines)
      hunks = diffs.map do |piece|
        Diff::LCS::Hunk.new(
                            expected_lines, actual_lines, piece, 3, 0
                            ).tap do |h|
          file_length_difference = h.file_length_difference 
        end
      end

      hunks.each_cons(2) do |prev_hunk, current_hunk|
        begin
          if current_hunk.overlaps?(prev_hunk)
            current_hunk.merge(prev_hunk)
          else
            output << prev_hunk.diff(:unified).to_s
          end
        rescue => e
        end
      end

      if hunks.last
        output << hunks.last.diff(:unified).to_s
      end

      output
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

    def run_procs(script, cmd, engine=nil)
      engine ||= @engine
      display_name = script[:header][:name]

      if @runmode == 'idempotent'
        case
        when script[:header][:if]
          block_name = script[:header][:if]
          exit_status = @procs_exit_status[block_name]
          unless exit_status == 0
            logger.info "#{display_name.fg 'green'} -- Skipped since :if clause matches check from '#{block_name.fg 'yellow'}'"
            return
          end
        when script[:header][:unless]
          block_name = script[:header][:unless]
          exit_status = @procs_exit_status[block_name]
          if exit_status == 0
            logger.info "#{display_name.fg 'green'} -- Skipped since :unless clause matches check from '#{block_name.fg 'yellow'}'"
            return
          end
        end
      end

      if script[:header][:procs]
        procs = script[:header][:procs].to_i
        1.upto(procs) do |i|
          proc_name = "#{display_name}:#{i}"
          engine.register proc_name, cmd, { :cwd => @root_dir, :logger => logger,  :header => script[:header] }
        end
      else
        engine.register display_name, cmd, { :cwd => @root_dir, :logger => logger, :header => script[:header] }
      end
    end

    def determine_lang_bin(script)
      if script[:header][:shebang]
        script[:header][:shebang].gsub('#!', '')
      else
        script[:lang]
      end
    end
  end
end
