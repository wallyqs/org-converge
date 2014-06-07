module OrgConverge
  module Helpers
    def determine_lang_bin(script)
      if script[:header][:shebang]
        script[:header][:shebang].gsub('#!', '')
      else
        script[:lang]
      end
    end

    def determine_ssh_params(dir)
      ssh = { }

      if dir =~ /\/(([^ @:]+)@)?([^ #:]+)?#?(\d+)?:(.*)?/
        ssh[:user] = $2
        ssh[:host] = $3
        ssh[:port] = ($4 || 22).to_i
        ssh[:remote_dir] = ($5 || '')
      end

      ssh
    end
  end
end
