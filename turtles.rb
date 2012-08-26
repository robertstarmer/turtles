#
# Copyright 2012, Piston Cloud Computing, Inc.
# All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
#
#
#
#
# DO NOT USE


require 'fog'
require 'fileutils'
require 'open3'
require 'optparse'
require 'yaml'

def generate_password(length=36)
  (36**(length-1) + rand(36**length)).to_s(36)
end

def salted_password(password)
  `mkpasswd -m sha-512 '#{password}'`.strip
end

class Bosh
  def initialize(password, os_auth_url, os_username, os_api_key, os_tenant)
    @password = salted_password(password)
    @name = "microbosh-openstack"
    @os_auth_url = os_auth_url
    @os_username = os_username
    @os_api_key = os_api_key
    @os_tenant = os_tenant
  end

  def env
    {:env => {:bosh => {:password => @password}}}
  end

  def manifest(config, manifest_path)
    manifest_file = File.join(File.dirname(__FILE__), 'openstack_micro.tmpl')
    manifest_template = ERB.new(IO.read(manifest_file))

    File.open(File.join(manifest_path, "openstack_micro.yml"), "w") do |f|
      f.write(manifest_template.result binding)
    end
  end

  def deployment(config, deployment_path)
    deployment_file = File.join(File.dirname(__FILE__), 'deployment_micro.tmpl')
    deployment_template = ERB.new(IO.read(deployment_file))

    File.open(File.join(deployment_path, "micro_bosh.yml"), 'w') do |f|
      f.write(deployment_template.result binding)
    end
  end

  def config(domain=nil)
    cfg = {'domain' => domain}

    %w(nats postgres director agent registry director_account).map {|n|
      cfg["generated_#{n}_pass"] = generate_password
    }
    cfg
  end

  def deploy(config)
    # First build custom bosh manifest and deployment files.
    manifest_path = "/var/vcap/manifests"
    deployment_path = "/var/vcap/deployments/microbosh-openstack"
    manifest_config = config(config['domain'])
    deployment_config = manifest_config.dup

    FileUtils.mkdir_p([manifest_path, deployment_path])
    manifest(manifest_config, manifest_path)
    deployment(deployment_config, deployment_path)

    stemcell_path = "Fake"


    stemcell_build_options = ['openstack', File.join(manifest_path, 'openstack_micro.yml'),
 			      '/var/vcap/releases/bosh-release/dev_releases/bosh-7.1-dev.tgz']

    # Second build the stemcell if it doesn't exist.
    stemcells = Dir.entries('/var/vcap/stemcells/').reject {|f| ['.', '..'].include? f }
    if stemcells.empty?
      Dir.chdir("/var/vcap/bootstrap/bosh/agent") do 
        output, error = Open3.capture3("rake", "stemcell2:micro[#{stemcell_build_options.join(',')}]") 
        
        output = output.split('/n')
        stemcell_path = output.map { |l| l.gsub(/.*: /, '') if l =~ /generated stemcell/i }[0]
      end

      # Move the stemcell someplace reasonable.
      FileUtils.mv stemcell_path, '/var/vcap/stemcells/'
    else
      stemcell_path = File.join("/var/vcap/stemcells", stemcells[0])
    end

    Dir.chdir("/var/vcap/deployments") do
      `bosh micro deployment microbosh-openstack`
      puts `bosh micro deployment #{stemcell_path}`
    end
  end
end


class CloudFoundry
  def phase_one(config)

  end

  def phase_two(config)
  end

  def deploy

  end
end

if self.inspect == 'main'
  # DO STUFF
  #
  cpi = OpenStack.new("admin", "lincolncoin", "CloudFoundry",
                      "http://64.151.120.3:5000/v2.0/tokens")
  
  b = Bosh.new("fuckinga", "http://64.151.120.3:5000/v2.0/tokens",
               "admin", "lincolncoin", "CloudFoundry")

  b.deploy({'domain' => "vcap.me"})

  puts b.manifest(b.config)



#  puts YAML::dump(stringify_keys(b.config('poop', 'morepoop', {'name' => 12345, 'path' => '/path/to/fake'})))
end

