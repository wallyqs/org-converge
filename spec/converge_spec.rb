require 'spec_helper'

describe OrgConverge::Command do
  context "when converging 'basic_tangle'" do
    example_dir = File.join(EXAMPLES_DIR, 'basic_tangle')

    it "should tangle a 'conf.yml' file" do
      setup_file = File.join(example_dir, 'setup.org')
      o = OrgConverge::Command.new({ 
                                     '<org_file>' => setup_file,
                                     '--root-dir' => example_dir
                                   })
      success = o.execute!
      success.should == true

      expected_contents = File.read(File.join(example_dir, 'conf.yml.expected'))

      resulting_file = File.join(example_dir, 'conf.yml')
      File.exists?(resulting_file).should == true

      result = File.read(resulting_file)

      result.should == expected_contents
    end
  end

  context "when converging 'basic_run_example'" do
    example_dir = File.join(EXAMPLES_DIR, 'basic_run_example')
    setup_file = File.join(example_dir, 'setup.org')
    o = OrgConverge::Command.new({ 
                                   '<org_file>' => setup_file,
                                   '--root-dir' => example_dir
                                 })
    success = o.execute!
    success.should == true

    expected_contents = File.read(File.join(example_dir, 'out.log'))
    expected_contents.lines.count.should == 16
  end
end


