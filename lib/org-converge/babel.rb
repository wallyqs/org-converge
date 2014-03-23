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

    # TODO: should be able to tangle relatively to a dir
    def tangle!
      logger.info "Tangling #{ob.tangle.keys.count} files..."

      ob.tangle.each do |tangle_file, lines|
        file = if @root_dir
                 File.join(@root_dir, tangle_file)
               else
                 tangle_file
               end

        logger.info "BEGIN(#{tangle_file}): Tangling #{lines.count} lines at '#{file}'"
        # TODO: should abort when the directory does not exists
        # TODO: should abort when the directory failed because of permissions
        if not Dir.exists?(File.dirname(file))
          logger.error "Could not tangle #{file} because directory does not exists!"
          raise TangleError
        end

        if File.exists?(file)
          logger.warn "File already exists at #{file}, it will be overwritten"
        end

        begin
          File.open(file, 'w') do |f|
            lines.each do |line|
              f.puts line
            end
          end
        rescue => e
          logger.error "Problem while writing to '#{file}': #{e}"
          raise TangleError
        end
        logger.info "END(#{file}): done."
      end

      logger.info "Tangling succeeded!".green
    end

    class TangleError < Exception; end
  end
end