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

    resulting_file = File.join(example_dir, 'config/hello.yml')
    File.exists?(resulting_file).should == true
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

  it "should run specified block from 'specified_block' example" do
    example_dir = File.join(EXAMPLES_DIR, 'specified_block')
    setup_file = File.join(example_dir, 'run.org')
    o = OrgConverge::Command.new({ 
                                   '<org_file>' => setup_file,
                                   '--root-dir' => example_dir,
                                   '--name'     => 'first'
                                 })
    success = o.execute!
    success.should == true

    expected_contents = File.read(File.join(example_dir, 'same.log'))
    expected_contents.lines.count.should == 1
    expected_contents.should == "First block\n"
  end

  it "should run not commented blocks from 'commented_block' example" do
    example_dir = File.join(EXAMPLES_DIR, 'commented_block')
    setup_file = File.join(example_dir, 'run.org')
    o = OrgConverge::Command.new({ 
                                   '<org_file>' => setup_file,
                                   '--root-dir' => example_dir,
                                 })
    success = o.execute!
    success.should == true

    expected_contents = File.read(File.join(example_dir, 'output.log'))
    expected_contents.lines.count.should == 2
    expected_contents.should == "first\nthird\n"
  end

  it "should converge 'runlist_example' sequentially" do
    example_dir = File.join(EXAMPLES_DIR, 'runlist_example')
    setup_file = File.join(example_dir, 'setup.org')

    o = OrgConverge::Command.new({ 
                                   '<org_file>' => setup_file,
                                   '--root-dir' => example_dir
                                 })
    success = o.execute!
    success.should == true

    File.executable?(File.join(example_dir, 'run/0')).should == true
    File.executable?(File.join(example_dir, 'run/1')).should == true
    expected_contents = "first\nsecond\n"
    File.read(File.join(example_dir, 'out.log')).should == expected_contents
  end
end
