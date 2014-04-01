require 'spec_helper'

describe OrgConverge::Command do

  it "should converge 'basic_tangle'" do
    example_dir = File.join(EXAMPLES_DIR, 'basic_tangle')

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

  it "should converge 'basic_run_example'" do
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

  it "should converge 'runlist_example' sequentially" do
    example_dir = File.join(EXAMPLES_DIR, 'runlist_example')
    setup_file = File.join(example_dir, 'setup.org')

    o = OrgConverge::Command.new({ 
                                   '<org_file>' => setup_file,
                                   '--root-dir' => example_dir
                                   '--runmode'  => 'sequential'
                                 })
    success = o.execute!
    success.should == true

    File.executable?(File.join(example_dir, 'run/0')).should == true
    File.executable?(File.join(example_dir, 'run/1')).should == true
    expected_contents = "first\nsecond"
    File.read(File.join(example_dir, 'out.log')).should == expected_contents
  end
end
