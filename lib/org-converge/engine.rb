#
# Re-use most of the proven tricks from Foreman for this
# and just customize to watch the output from runnable code blocks
#
require 'foreman/engine'
require 'foreman/process'

module OrgConverge
  class Engine < Foreman::Engine

    attr_reader :logger
    attr_reader :babel

    def initialize(options={})
      super(options)
      @logger = options[:logger] || Logger.new(STDOUT)
      @babel  = options[:babel]
    end

    # We allow other processes to exit with 0 status
    # to continue with the runlist
    def start
      register_signal_handlers
      spawn_processes
      watch_for_output
      sleep 0.1
      begin
        status = watch_for_termination        
      end while @running.count > 0
    end

    # Overriden: we do not consider process formations
    def spawn_processes
      @processes.each do |process|
        reader, writer = create_pipe
        begin
          pid = process.run(:output => writer)
          @names[process] = "#{@names[process]}(#{pid})"
          writer.puts "started with pid #{pid}"
        rescue Errno::ENOENT
          writer.puts "unknown command: #{process.command}"
        end
        @running[pid] = [process]
        @readers[pid] = reader
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
        ps = name.empty? ? '<defunct>' : name.split('.').first
        output  = "#{pad_process_name(ps)}".yellow
        output += " -- "
        output += message
        # FIXME: When the process has stopped already,
        # the name of the process does not appear
        logger.info output
      end
    rescue Errno::EPIPE
      terminate_gracefully
    end

    private
    def name_padding
      @name_padding ||= begin
                          name_padding  = @names.values.map { |n| n.length }.sort.last
                          [ 9, name_padding ].max
                        end
    end

    def pad_process_name(name)
      name.ljust(name_padding, " ")
    end
  end

  class CodeBlockProcess < Foreman::Process; end
end
