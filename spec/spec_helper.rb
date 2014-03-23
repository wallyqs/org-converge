require 'org-converge'
require 'fileutils'

RESULTS_DIR = File.expand_path("/tmp/#{Time.now.strftime("test_%s")}", File.dirname(__FILE__))
FileUtils.mkdir_p(RESULTS_DIR)
