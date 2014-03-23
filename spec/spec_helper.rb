require 'org-converge'
require 'fileutils'

RESULTS_DIR  = File.expand_path("tmp/#{Time.now.strftime("test_%s")}", File.dirname(__FILE__))
SPEC_DIR     = File.dirname(File.expand_path('.', __FILE__))
EXAMPLES_DIR = File.join(SPEC_DIR, 'converge_examples')
