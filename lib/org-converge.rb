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
