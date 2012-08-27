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


require 'highline/import'
require 'fileutils'
require 'fog'
require 'pty'
require 'expect'


@agent_path      = '/var/vcap/bootstrap/bosh/agent'
@deployment_path = '/var/vcap/deployments'
@manifest_path   = '/var/vcap/manifests'
@releases_path   = '/var/vcap/releases'
@stemcell_path   = '/var/vcap/stemcells'

@release_tarball = '/var/vcap/releases/bosh-release/dev_releases/bosh-7.1-dev.tgz'

@chars = %w( | / - \\ )
def spin
  print @chars[0]
  @chars.push @chars.shift
  print "\b"
end

def execute(command, pattern=nil, verbose=false, &block)
  #  $expect_verbose = verbose
  
  matches = []
  ex_out, ex_in, ex_pid = PTY.spawn(command)
  begin
    while line = ex_out.readline
      if verbose
        puts line
      else
        spin
      end

      # Do things with the data.
      if pattern and line =~ pattern
        if block
          block.call(ex_in, ex_out)
        else
          matches << line
        end
      end
    end
  rescue Errno::EIO
  end

  matches
end

def deploy_microbosh(config)
  def write_build_manifest(config, out_path)
    FileUtils.mkdir_p(File.dirname(out_path))

    t = ERB.new(IO.read('openstack_micro.tmpl'))
    File.open(out_path, 'w') do |f|
      f.write(t.result binding)
    end
  end

  def write_deployment_manifest(config, out_path)
    FileUtils.mkdir_p(File.dirname(out_path))

    t = ERB.new(IO.read('deployment_micro.tmpl'))
    File.open(out_path, 'w') do |f|
      f.write(t.result binding)
    end
  end

  # Ensure bosh config
  config = bosh_config unless config

  # Generate manifests
  manifest = File.join(@manifest_path, 'openstack_micro.yml')
  deployment_manifest = File.join('microbosh-openstack', 'micro_bosh.yml')

  write_build_manifest(config['manifest'], manifest)
  write_deployment_manifest(config['bosh'], File.join(@deployment_path, deployment_manifest))

  # Build stemcell and move it someplace safe.
  build_options = ['openstack', manifest, @release_tarball]
  rake_command = "cd #{@agent_path}; rake stemcell2:micro[#{build_options.join(',')}]"

  stemcells = Dir.entries(@stemcell_path).reject {|p| %w(. ..).include? p }
  if stemcells.empty?
    puts "This next step will take a while."
    print "Creating stemcell... "
    stemcell_path = execute(rake_command, /Generated stemcell/i)[0]
    stemcell_path.gsub!(/generated stemcell:\s+/i,'').strip!

    execute("sudo chown -R vcap:vcap #{File.dirname(stemcell_path)}")
    puts "done"

    FileUtils.cp stemcell_path.strip, @stemcell_path, :verbose => true

    stemcell_path = File.join(@stemcell_path, File.basename(stemcell_path))
  else
    stemcell_path = File.join(@stemcell_path, stemcells.first)
  end

  # Deploy
  microbosh = File.dirname(deployment_manifest)

  Dir.chdir(@deployment_path) do
    puts `bosh --non-interactive micro deployment #{microbosh}`
  end

  execute("cd #{@deployment_path}; bosh --non-interactive micro deploy #{stemcell_path}", pattern=nil, verbose=true) 
end

def deploy_cloudfoundry
  def install_release
    release_dir = File.join(@releases_path, 'cloudfoundry-release')

    Dir.chdir(@release_dir) do
      puts `bosh --non-interactive upload release`
    end
  end

  def deploy_cloudfoundry_stage_1
    # Generate manifest
    deployment_manifest = File.join('cloudfoundry', 'cloudfoundry.yml')

    # Upload release
    install_release

    # Create deployment
    Dir.chdir(@deployment_path) do
      puts `bosh --non-interactive deployment #{deployment_manifest}`
    end

    # Deploy
    puts `bosh --non-interactive deploy`

    # Detect new instances
    
  end

  def deploy_cloudfoundry_stage_2
    # Generate manifest
    # Deploy
  end
end

def target_microbosh(host, credentials)
  execute('bosh target #{host}')
  execute('bosh login', /username:/) do |input, output|
    input.printf("#{credentials[:username]}\n")
    output.expect(/password:/) do
      input.printf("#{credentials[:password]}\n")
    end
  end
end

def get_openstack_credentials
  os_auth_url = ask("Your OpenStack auth-url: ").to_s
  os_username = ask("Your OpenStack username: ").to_s
  os_tenant   = ask("Your OpenStack tenant: ").to_s
  os_api_key  = ask("Your OpenStack API key: ") { |q| q.echo = '*' }.to_s

  {'openstack_auth_url' => os_auth_url,
   'openstack_username' => os_username,
   'openstack_tenant'   => os_tenant,
   'openstack_api_key'  => os_api_key,}
end

def generate_password(length=36, salted=false)
  password = (36 ** (length-1) + rand(36 ** length)).to_s(36)
  salted_password = `mkpasswd -m sha-512 "#{password}"`.strip if salted

  if salted_password
    [password, salted_password]
  else
    password
  end
end

def generate_keypair(name='deployer', creds=nil)
  key_name = "bosh-#{name}"
  key_path = File.expand_path("~/.ssh/#{key_name}.pem")
  unless File.exist?(key_path)
    creds = get_openstack_credentials if creds.nil? or creds.empty?
    creds = creds.dup.inject({}) { |h, (k, v)| h[k.to_sym] = v; h }

    conn = Fog::Compute.new({:provider => "OpenStack",}.update(creds))
    keypair = conn.key_pairs.create(:name => key_name)
    keypair.write(key_path)

    FileUtils.chown 'vcap', 'vcap', key_path
  end

  {'name' => key_name, 'path' => key_path}
end


def bosh_config(creds=nil)
  domain = ask("Your bosh domain (Enter for default): ")
  creds = get_openstack_credentials if creds.nil? or creds.empty?
  key = generate_keypair(name=generate_password(length=8), creds)

  director_pass = generate_password

  bosh_password, salted_bosh_password = generate_password(length=36, salted=true)

  {'bosh' => {'cpi_creds' => creds,
              'bosh_password' => bosh_password,
              'salted_password' => salted_bosh_password,
              'director_pass' => director_pass,
              'key' => key},
   'manifest' => {'domain' => domain,
                  'nats_pass' => generate_password,
                  'postgres_pass' => generate_password,
                  'director_pass' => director_pass,
                  'agent_pass' => generate_password,
                  'registry_pass' => generate_password,
                  'director_account_pass' => generate_password}}
end
