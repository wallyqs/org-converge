require 'spec_helper'

describe OrgConverge::Helpers do
  include OrgConverge::Helpers

  tests = []
  tests << { 
    :dir => '/vagrant@127.0.0.1#2222:/home/vagrant/',
    :expected_user => "vagrant",
    :expected_host => "127.0.0.1",
    :expected_port => 2222,
    :expected_remote_dir => "/home/vagrant/"
  }
  tests << { 
    :dir => '/vagrant@127.0.0.1:/home/vagrant/',
    :expected_user => "vagrant",
    :expected_host => "127.0.0.1",
    :expected_port => 22,
    :expected_remote_dir => '/home/vagrant/'
  }
  tests << { 
    :dir => '/vagrant@127.0.0.1:',
    :expected_user => "vagrant",
    :expected_host => "127.0.0.1",
    :expected_port => 22,
    :expected_remote_dir => ''
  }
  tests << { 
    :dir => '/127.0.0.1:',
    :expected_user => nil,
    :expected_host => "127.0.0.1",
    :expected_port => 22,
    :expected_remote_dir => ''
  }
  tests << { 
    :dir => '/var/lib/org/',
    :expected_user => nil,
    :expected_host => nil,
    :expected_port => nil,
    :expected_remote_dir => nil
  }
  tests << { 
    :dir => 'org/',
    :expected_user => nil,
    :expected_host => nil,
    :expected_port => nil,
    :expected_remote_dir => nil
  }
  tests.each do |t|
    it "should parse ':dir #{t[:dir]}'" do
      ssh = determine_ssh_params(t[:dir])
      ssh[:user].should == t[:expected_user]
      ssh[:host].should == t[:expected_host]
      ssh[:port].should == t[:expected_port]
      ssh[:remote_dir].should == t[:expected_remote_dir]
    end
  end
end
