#
# Re-use most of the proven tricks from Foreman for this
# and just customize to watch the output from runnable code blocks
#
require 'foreman/engine'
require 'foreman/process'
require 'tco'
require 'fileutils'

module OrgConverge
  class Engine < Foreman::Engine

    attr_reader :logger
    attr_reader :babel

    RAINBOW = ["#622e90", "#2d3091", "#00aaea", "#02a552", "#fdea22", "#eb443b", "#f37f5a"]

    def initialize(options={})
      super(options)
      @logger  = options[:logger] || Logger.new(STDOUT)
      @babel   = options[:babel]
      @runmode = options[:runmode]

      # Code blocks whose start invocation is manipulated run inside a thread
      @threads = []
      @running_threads = { }
    end

    # We allow other processes to exit with 0 status
    # to continue with the runlist
    def start
      register_signal_handlers
      spawn_processes
      watch_for_output
      sleep 0.1
      begin
        status = watch_for_termination do
          @threads.each do |t|
            unless t.alive?
              t.exit
              @running_threads.delete(t.__id__)
            end
          end
        end
      end while (@running.count > 0 or @running_threads.count > 0)
    end

    # Overriden: we do not consider process formations
    def spawn_processes
      @processes.each do |process|
        reader, writer = create_pipe
        pid    = nil
        thread = nil
        begin
          # In case of spec mode, we need to redirect the output to a results file instead
          writer = File.open(process.options[:results], 'a') if @runmode == 'spec'
          pid, thread = process.run(:output => writer, :header => process.options[:header])
          @names[process] = "#{@names[process]}.#{pid || thread.__id__}"

          # NOTE: In spec mode we need to be more strict on what is flushed by the engine
          # because we will be comparing the output
          unless @runmode == 'spec'
            writer.puts "started with pid #{pid}" if pid
            writer.puts "started thread with tid #{thread.__id__}" if thread
          end
        rescue Errno::ENOENT
          writer.puts "unknown command: #{process.command}" unless @runmode == 'spec'
        end

        @running[pid] = [process] if pid
        @readers[pid || thread.__id__] = reader
        if thread
          @threads << thread
          @running_threads[thread.__id__] = [process]
        end
      end
    end

    def register(name, command, options={})
      options[:env] ||= env
      options[:cwd] ||= File.dirname(command.split(" ").first)
      process = OrgConverge::CodeBlockProcess.new(command, options)
      @names[process] = name
      @processes << process
    end

    def output(name, data)
      data.to_s.lines.map(&:chomp).each do |message|
        # FIXME: In case the process has finished before its lines where flushed
        output = "#{name} -- #{message}"
        ps, pid = name.empty? ? '<defunct>' : name.split('.')
        output  = "#{pad_process_name(ps)}".fg get_color_for_pid(pid.to_i)
        output += " -- "
        output += message

        # FIXME: When the process has stopped already, the name of the process/thread does not appear
        #        (which means that this approach is wrong from the beginning probably)
        logger.info output
      end
    rescue Errno::EPIPE
      terminate_gracefully
    end

    private
    def name_padding
      @name_padding ||= begin
                          name_padding  = @names.values.map { |n| n.split('.').first.length }.sort.last
                          [ 9, name_padding ].max
                        end
    end

    def pad_process_name(name)
      name.ljust(name_padding, " ")
    end

    def get_color_for_pid(pid)
      RAINBOW[pid % 7]
    end

    def watch_for_termination
      pid, status = Process.wait2
      output_with_mutex name_for(pid), termination_message_for(status) unless @runmode == 'spec'
      @running.delete(pid)
      yield if block_given?
      pid
    rescue Errno::ECHILD
    end

    def name_for(pid)
      process = nil
      index   = nil
      if @running[pid]
        process, index = @running[pid]
      elsif @running_threads[pid]
        process, index = @running_threads[pid]
      end
      name_for_index(process, index)
    end

    def name_for_index(process, index)
      [ @names[process], index.to_s ].compact.join(".")
    end
  end

  # Need to expose the options to make the process be aware
  # of the possible running mode (specially spec mode)
  # and where to put the results output
  require 'timeout'
  class CodeBlockProcess < Foreman::Process
    attr_reader :options

    def run(options={})
      env    = @options[:env].merge(options[:env] || {})
      output = options[:output] || $stdout
      runner = "#{Foreman.runner}".shellescape

      # whitelist the modifiers which manipulate how to the block is started
      block_modifiers = { }
      if options[:header]
        block_modifiers[:waitfor] = options[:header][:waitsfor]  || options[:header][:waitfor] || options[:header][:sleep]
        block_modifiers[:timeout] = options[:header][:timeoutin] || options[:header][:timeout] || options[:header][:timeoutafter]
        if options[:header][:dir]
          block_modifiers[:cwd] = File.expand_path(File.join(self.options[:cwd], options[:header][:dir]))
        end
      end

      pid     = nil
      thread  = nil

      process = proc do
        wrapped_command = ''
        if block_modifiers[:cwd]
          @options[:cwd] = block_modifiers[:cwd]
          # Need to adjust the path by having the run file at the same place
          bin, original_script = command.split(' ')
          new_script           = File.join(block_modifiers[:cwd], ".#{options[:header][:name]}")
          FileUtils.cp(original_script, new_script)
          cmd = [bin, new_script].join(' ')
          wrapped_command = "exec #{runner} -d '#{cwd}' -p -- #{cmd}"
        else
          wrapped_command = "exec #{runner} -d '#{cwd}' -p -- #{command}"
        end
        opts = { :out => output, :err => output }
        pid  = Process.spawn env, wrapped_command, opts
      end

      if block_modifiers and (block_modifiers[:waitfor] || block_modifiers[:timeout] || block_modifiers[:dir])
        waitfor = block_modifiers[:waitfor].to_i
        timeout = block_modifiers[:timeout].to_i

        thread = Thread.new do
          sleep waitfor if waitfor > 0
          pid = process.call
          if timeout > 0
            sleep timeout
            puts "PPID: #{pid}"
            o = `ps -ef | awk '$3 == #{pid} { print $2 }'`
            o.each_line do |cpid|
              Process.kill(:TERM, cpid.to_i)
            end
            Process.kill(:TERM, pid)
            Thread.current.kill
          end
        end
      else
        if Foreman.windows?
          Dir.chdir(cwd) { pid = Process.spawn env, expanded_command(env), :out => output, :err => output }
        else
          pid = process.call
        end
      end

      # In case of thread, pid will be nil
      return pid, thread
    end
  end
end
