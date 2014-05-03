#
# Class with util methods that try to reimplement some of
# the functionality provided by Org Babel from Emacs
#
require 'fileutils'

module Orgmode
  class Babel
    attr_reader :ob     # Babel Output Buffer with parsed contents
    attr_reader :logger

    def initialize(babel_output_buffer, options={})
      @ob = babel_output_buffer
      @options = options
      @logger  = options[:logger] || Logger.new(STDOUT)
      @root_dir = options[:root_dir]
    end

    def tangle!
      logger.info "Tangling #{ob.tangle.keys.count} files..."

      ob.tangle.each do |tangle_file, script|
        file = if @root_dir
                 File.join(@root_dir, tangle_file)
               else
                 tangle_file
               end

        logger.info "BEGIN(#{tangle_file}): Tangling #{script[:lines].split('\n').count} lines at '#{file}'"
        # TODO: should abort when the directory failed because of permissions
        # TODO: should apply :tangle-mode for permissions
        directory = File.expand_path(File.dirname(file))
        if not Dir.exists?(directory)
          begin
            if script[:header][:mkdirp] == 'true'
              logger.info "Create dir for #{file} since it does not exists..."
              FileUtils.mkdir_p(File.dirname(file), :mode => 0755)
            else
              logger.warn "Cannot tangle #{file} because directory does not exists!"
            end
          rescue => e
            p e
            raise TangleError
          end
        end

        if File.exists?(file)
          logger.warn "File already exists at #{file}, it will be overwritten"
        end

        begin
          File.open(file, 'w') do |f|
            script[:lines].each_line do |line|
              f.puts line
            end
          end
        rescue => e
          logger.error "Problem while writing to '#{file}': #{e}"
          raise TangleError
        end
        logger.info "END(#{file}): done."
      end

      logger.info "Tangling succeeded!"
    end

    def tangle_runnable_blocks!(run_dir='run', options={})
      FileUtils.mkdir_p(run_dir)

      logger.info "Tangling #{ob.scripts.count} scripts within directory: #{run_dir}..."

      ob.scripts.each_pair do |script_key, script|
        file = script_key.to_s
        logger.warn "File already exists at #{file}, it will be overwritten" if File.exists?(file)

        # Files with :shebang are executable by default
        File.open(File.join(run_dir, file), 'w', 0755) do |f|
          script[:lines].each_line do |line|
            f.puts line
          end
        end
      end
    end

    class TangleError < Exception; end
  end
end
