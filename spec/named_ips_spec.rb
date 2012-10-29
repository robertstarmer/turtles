require File.expand_path("../spec_helper", __FILE__)

describe Turtles::NamedIP do

  before(:each) do 
    Fog.mock!
    Fog::Mock.reset
  end

  after(:each) do
    Fog.unmock!
  end

  it "consistently returns an IP for a given name" do
    ip_foo = Turtles::NamedIP.get_ip("foo")
    ip_foo.length.should be_between(7, 15)

    ip_foo_again = Turtles::NamedIP.get_ip("foo")
    ip_foo_again.should equal ip_foo
  end

  it "return different IPs for different names" do
    ip_foo = Turtles::NamedIP.get_ip("foo")
    ip_bar = Turtles::NamedIP.get_ip("bar")
    ip_foo.should_not equal ip_bar
  end

  it "allocates an IP when there are no IPs" do
    Turtles.cloud.addresses.length.should == 0
    Turtles::NamedIP.get_ip("foo")
    Turtles.cloud.addresses.length.should == 1
  end

  it "allocates an IP when all IPs are assigned" do
    3.times do 
      server = Turtles.cloud.servers.create
      ip = Turtles.cloud.addresses.create
      ip.server = server
    end
    Turtles.cloud.addresses.length.should == 3
    Turtles::NamedIP.get_ip("foo")
    Turtles.cloud.addresses.length.should == 4
  end

  it "does not allocate an IP when there are unassigned IPs" do
    Turtles.cloud.addresses.length.should == 0
    2.times do 
      Turtles.cloud.addresses.create
    end
    Turtles.cloud.addresses.length.should == 2
    Turtles::NamedIP.get_ip("foo")
    Turtles::NamedIP.get_ip("bar")
    Turtles.cloud.addresses.length.should == 2
  end
end
