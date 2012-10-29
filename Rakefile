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
  if provider
    File.join([TURTLES_DIR, 'data', PROVIDER, filename])
  else
    File.join([TURTLES_DIR, 'data', filename])
  end
end

def script_file(filename)
  File.join([TURTLES_DIR, 'scripts', filename])
end

turtles_pk = File.join([WORK_DIR, 'turtles.pem'])

deploy_dir = File.join([WORK_DIR, 'deployments'])
micro_bosh_deploy_dir = File.join([deploy_dir, 'micro'])
micro_bosh_deploy_config = File.join([micro_bosh_deploy_dir, 'micro_bosh.yml'])
micro_bosh_stemcell = File.join([WORK_DIR, 'micro-bosh-stemcell.tgz'])

directory WORK_DIR

file micro_bosh_stemcell => WORK_DIR do |t|
  if PREBUILT_STEMCELL
    # we're just going to use the prebuilt stemcell later
    touch t.name 
  else
    cd WORK_DIR
    rm_rf 'bosh-release'
    sh 'git clone git://github.com/cloudfoundry/bosh-release.git'
    cd 'bosh-release' do
      sh "#{script_file('fix_gitmodules.sh')} #{pwd}/.gitmodules"
      sh 'git submodule update --init'
      sh 'git stash'
      cp data_file('bosh-release-config.yml'), 'config/dev.yml' 
      sh 'bosh create release --with-tarball'
      tarball = pwd + '/' + Dir['dev_releases/*.tgz'].first
      cd 'src/bosh/agent' do
        sh 'bundle install --without=development test'
        manifest = data_file('micro_bosh_stemcell.yml')
        sh "rake stemcell2:micro[#{PROVIDER},#{manifest},#{tarball}]"
        stemcell = `find /var/tmp -name micro-bosh-stemcell*`.strip
        mv stemcell, t.name
      end
    end
  end
end

directory deploy_dir
directory micro_bosh_deploy_dir

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
  group = Turtles.cloud.security_groups.get("turtles-bosh-micro")
  if group.nil?
    group = Turtles.cloud.security_groups.new({
      :name => "turtles-bosh-micro",
      :description => "Bosh Micro Stack for Turtles"
    })
    group.save
    # too many ports to be specific yet
    group.authorize_port_range(0..65535)
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
