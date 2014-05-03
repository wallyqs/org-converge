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
      mark_trees_for_export

      # Feed the parsed contens and create the necessary internal structures
      # for doing babel like features
      output = ''
      babel_options = { 
        :in_buffer_settings => @in_buffer_settings
      }
      ob = BabelOutputBuffer.new(output, babel_options)
      translate(@header_lines, ob)
      @headlines.each do |headline|
        next if headline.export_state == :exclude
        translate(headline.body_lines, ob)
      end

      ob
    end
  end
end

require 'tco'
conf = Tco.config
conf.names["green"] = "#02a552"
conf.names["red"]   = "#eb443b"
Tco.reconfigure conf
