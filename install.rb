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


require 'fileutils'
require 'pty'
require 'expect'


@agent_path      = '/var/vcap/bootstrap/bosh/agent'
@deployment_path = '/var/vcap/deployments'
@manifest_path   = '/var/vcap/manifests'
@releases_path   = '/var/vcap/releases'
@stemcell_path   = '/var/vcap/stemcells'

@release_tarball = '/var/vcap/releases/bosh-release/dev_releases/bosh-7.1-dev.tgz'

def execute(command, pattern=nil, verbose=false, &block)
  $expect_verbose = verbose
  
  ex_out, ex_in, ex_pid = PTY.spawn(command)

  matches = ex_out.expect(pattern) if pattern
  if block and matches
    block.call(ex_in, ex_out)
  else
    matches
  end
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

    t = ERB.new(IO.read('deployment_manifest.tmpl'))
    File.open(out_path, 'w') do |f|
      f.write(t.result binding)
    end
  end

  # Generate manifests
  manifest = File.join(@manifest_path, 'openstack_micro.yml')
  deployment_manifest = File.join('microbosh-openstack', 'micro_bosh.yml')

  write_build_manifest(manifest)
  write_deployment_manifest(config, File.join(@deployment_path, deployment_path))

  # Build stemcell and move it someplace safe.
  build_options = ['openstack', manifest, @release_tarball]
  rake_command = "cd #{@agent_path}; rake stemcell2:micro[#{build_options.join(',')}]"
  stemcell_path = execute(rake_command, /generated stemcell .*?\r\n/i, verbose=true)[0]
  stemcell_path = "Generated stemcell: /var/tmp/bosh/agent-0.6.4-21778/work/work/micro-bosh-stemcell-openstack-0.6.4.tgz"
  stemcell_path.gsub!(/generated stemcell:\s+/i,'')

  execute("sudo chown -R vcap:vcap #{File.dirname(stemcell_path)}")

  # FileUtils.cp stemcell_path, @stemcell_path, :verbose => true

  stemcell_path = File.join(@stemcell_path, File.basename(stemcell_path))

  # Deploy

  microbosh = File.dirname(deployment_manifest)
  puts microbosh
  execute("cd #{@deployment_path}; bosh micro deployment #{microbosh}", /Deployment set to .*\r\n/i, verbose=true)

  execute("bosh micro deploy #{stemcell_path}", /type 'yes'/, verbose=true) do |input, output|
    input.printf("yes\n")
    output.expect(/target .*\n/) do |matches|

    end
  end
end

def deploy_cloudfoundry
  def install_release
    release_dir = File.join(@releases_path, 'cloudfoundry-release')
    release_command = "cd #{release_dir}; bosh upload release"
    execute(release_command, /Upload release/) do |input, output|
      input.printf("yes\n")
    end
  end

  def deploy_cloudfoundry_stage_1
    # Generate manifest
    deployment_manifest = File.join(@deployment_path, 'cloudfoundry', 'cloudfoundry.yml')

    # Upload release
    install_release

    # Create deployment
    execute('bosh deployment #{deployment_manifest}')

    # Deploy
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
