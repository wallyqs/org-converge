require 'org-ruby'
require 'org-converge/babel_output_buffer'
require 'org-converge/babel'
require 'org-converge/command'
require 'org-converge/engine'
require 'org-converge/version'

module Orgmode
  class Parser

    # This would return a babel output buffer which has the methods
    # needed in order to be able to tangle the files
    def babelize
      # Feed the parsed contens and create the necessary internal structures
      # for doing babel like features
      output = ''
      ob = BabelOutputBuffer.new(output)
      translate(@header_lines, ob)
      @headlines.each do |headline|
        translate(headline.body_lines, ob)
      end

      ob
    end
  end
end

module StringWithColors
  def red;    colorize("\e[0m\e[31m");  end
  def green;  colorize("\e[0m\e[32m");  end
  def yellow; colorize("\e[0m\e[33m");  end
  def bold;   colorize("\e[0m\e[1m");   end
  def colorize(color_code); "#{color_code}#{self}\e[0m"; end
end

class String
  include StringWithColors
end
