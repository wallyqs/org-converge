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
    end

    def tangle!
      logger.info "Tangling #{ob.tangle.keys.count} files..."

      ob.tangle.each do |file, lines|
        logger.info "Begin to tangle #{file} (lines: #{lines.count})"
        # should abort when the directory does not exists
        # should abort when the directory failed because of permissions
        if not Dir.exists?(File.dirname(file))
          logger.error "Could not tangle #{file} because directory does not exists!"
          raise TangleError
        end

        begin
          File.open(file, 'a') do |f|
            lines.each do |line|
              f.puts line
            end
          end
        rescue => e
          logger.error "Problem while writing to '#{file}': #{e}"
          raise TangleError
        end
      end

      logger.info "Tangling succeeded!".green
    end

    class TangleError < Exception; end
  end
end
