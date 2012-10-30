$:.unshift(File.expand_path("../lib", __FILE__))
require 'turtles'
require 'fog'

if ENV['HOME'] == '/Users/progrium'
  WORK_DIR = "/Users/progrium/Projects/turtles/work"
  TURTLES_DIR = "/Users/progrium/Projects/turtles/turtles"
  PREBUILT_STEMCELL = 'ami-7ac7494a' # for us-west-2
else
  WORK_DIR = File.expand_path("~/work")
  TURTLES_DIR = File.expand_path("~/turtles")
  PREBUILT_STEMCELL = nil
end

PROVIDER = Turtles.config['cloud'][:provider]

def data_file(filename, provider=false)
  File.join([TURTLES_DIR, 'data', provider ? PROVIDER : nil, filename].compact)
end
def turtles_path(*parts);   File.join(parts.unshift(TURTLES_DIR)); end
def work_path(*parts);      File.join(parts.unshift(WORK_DIR)); end

turtles_pk                = work_path('turtles.pem')
deploy_dir                = work_path('deployments')
bosh_release              = work_path('bosh-release.tgz')
micro_bosh_deploy_dir     = work_path('deployments', 'micro')
micro_bosh_deploy_config  = work_path('deployments', 'micro', 'micro_bosh.yml')
micro_bosh_stemcell       = work_path('micro-bosh-stemcell.tgz')
bosh_stemcell             = work_path('bosh-stemcell.tgz')

directory WORK_DIR
directory deploy_dir
directory micro_bosh_deploy_dir

def swift(*args, &block)
  auth_url = Turtles.config['cloud'][:openstack_auth_url]
  admin_key = Turtles.config['cloud'][:openstack_admin_key]
  sh "swift -A #{auth_url} -V 2.0 -U admin:admin -K #{admin_key} #{args.join(' ')}", &block
end

file bosh_release => WORK_DIR do |t|
  cd WORK_DIR
  sh 'git clone git://github.com/cloudfoundry/bosh-release.git'
  cd 'bosh-release' do
    sh "#{turtles_path('scripts', 'fix_gitmodules.sh')} #{pwd}/.gitmodules"
    sh 'git submodule update --init'
    sh 'git stash'
    cp data_file('bosh-release-config.yml'), 'config/dev.yml' 
    sh 'bosh create release --with-tarball'
    tarball = pwd + '/' + Dir['dev_releases/*.tgz'].first
    mv tarball, t.name
  end
end

file micro_bosh_stemcell => [bosh_release, WORK_DIR] do |t|
  if PREBUILT_STEMCELL or File.exist? t.name
    touch t.name
  else
    cd WORK_DIR
    cd 'bosh-release/src/bosh/agent' do
      sh 'bundle install --without=development test'
      manifest = data_file('micro_bosh_stemcell.yml')
      sh "rake stemcell2:micro[#{PROVIDER},#{manifest},#{bosh_release}]"
      stemcell = `find /var/tmp -name micro-bosh-stemcell*`.strip
      mv stemcell, t.name
    end
  end
end

file bosh_stemcell => [bosh_release, WORK_DIR] do |t|
  if File.exist? t.name
    touch t.name
  else
    cd WORK_DIR
    cd 'bosh-release/src/bosh/agent' do
      sh 'bundle install --without=development test'
      sh "rake stemcell2:basic[#{PROVIDER}]"
      stemcell = `find /var/tmp -name bosh-stemcell*`.strip
      mv stemcell, t.name
    end
  end
end

file micro_bosh_deploy_config => [micro_bosh_deploy_dir, turtles_pk] do |t|
  if Turtles.cloud.class.to_s.include? "OpenStack"
    openstack_auth_url = Turtles.config['cloud'][:openstack_auth_url]
    openstack_username = Turtles.config['cloud'][:openstack_username]
    openstack_api_key = Turtles.config['cloud'][:openstack_api_key]
    openstack_tenant = Turtles.config['cloud'][:openstack_tenant]
  else
    aws_region = Turtles.config['cloud'][:region]
    access_key_id = Turtles.config['cloud'][:aws_access_key_id]
    secret_access_key = Turtles.config['cloud'][:aws_secret_access_key]
  end
  ip = Turtles::NamedIP.get_ip("micro-bosh")
  private_keyfile = turtles_pk
  template = ERB.new(File.read(data_file('micro_bosh_deploy.yml.erb', true)))
  File.open(t.name, 'w') do |f|
    f.write(template.result(binding))
  end
end

file turtles_pk do |t|
  # runs if no pk file, so always recreate keypair
  keypair = Turtles.cloud.key_pairs.get("turtles")
  keypair.destroy if keypair
  keypair = Turtles.cloud.key_pairs.new :name => "turtles"
  keypair.save
  keypair.write(t.name)
end

task :micro_bosh_cloud_setup do
  if Turtles.cloud.class.to_s.include? "OpenStack"
    groups = Turtles.cloud.security_groups
    group = groups.find {|g| g.name == "turtles-bosh-micro" }
  else
    group = Turtles.cloud.security_groups.get("turtles-bosh-micro")
  end
  if group.nil?
    group = Turtles.cloud.security_groups.new({
      :name => "turtles-bosh-micro",
      :description => "Bosh Micro Stack for Turtles"
    })
    group.save
    # too many ports to be specific yet
    if Turtles.cloud.class.to_s.include? "OpenStack"
      group.create_security_group_rule(1, 65535)
    else
      group.authorize_port_range(0..65535)
    end
  end
end

task :micro_bosh_deploy =>
  [:micro_bosh_cloud_setup, micro_bosh_deploy_config, turtles_pk, micro_bosh_stemcell] do

  if PREBUILT_STEMCELL
    stemcell = PREBUILT_STEMCELL
  else
    stemcell = micro_bosh_stemcell
  end
  cd deploy_dir do
    sh "bosh -n micro deployment micro"
    sh "bosh -n micro deploy #{stemcell}"
    sh "bosh -n target http://#{Turtles::NamedIP.get_ip("micro-bosh")}:25555"
    sh "bosh -n login admin admin"
    sh "bosh status"
  end
end

task :micro_bosh_delete do
  cd deploy_dir do
    sh "bosh -n micro delete"
  end
end

task :reset do
  rm_rf WORK_DIR
end

task :swift do
  sh "pip install #{turtles_path('pkgs', 'swift.tar.gz')}"
end

task :download_stemcells => [:swift, WORK_DIR] do
  cd WORK_DIR
  swift 'download', 'turtles', 'bosh-stemcell.tgz'
  swift 'download', 'turtles', 'micro-bosh-stemcell.tgz'
end
