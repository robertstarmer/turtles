$:.unshift(File.expand_path("../lib", __FILE__))
require 'turtles'
require 'fog'

if ENV['HOME'] == '/Users/progrium'
  WORK_DIR = "/Users/progrium/Projects/turtles/work"
  TURTLES_DIR = "/Users/progrium/Projects/turtles/turtles"
else
  WORK_DIR = File.expand_path("~/work")
  TURTLES_DIR = File.expand_path("~/turtles")
end

CLOUD_ARCH = 'aws'

def data_file(filename, arch=false)
  if arch
    File.join([TURTLES_DIR, 'data', CLOUD_ARCH, filename])
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
      manifest = data_file('micro_bosh_stemcell.yml', true)
      sh "rake stemcell2:micro[#{CLOUD_ARCH},#{manifest},#{tarball}]"
      stemcell = `find /var/tmp -name micro-bosh-stemcell*`.strip
      mv stemcell, t.name
    end
  end
end

directory deploy_dir
directory micro_bosh_deploy_dir

file micro_bosh_deploy_config => [micro_bosh_deploy_dir, turtles_pk] do |t|
  ip = Turtles::NamedIP.get_ip("micro-bosh")
  aws_region = Turtles.config['cloud'][:region]
  access_key_id = Turtles.config['cloud'][:aws_access_key_id]
  secret_access_key = Turtles.config['cloud'][:aws_secret_access_key]
  private_keyfile = turtles_pk
  template = ERB.new(File.read(data_file('micro_bosh_deploy.yml.erb', true)))
  File.open(t.name, 'w') do |f|
    f.write(template.result(binding))
  end
end

file turtles_pk do |t|
  keypair = Turtles.cloud.key_pairs.get("turtles")
  if keypair.nil?
    keypair = Turtles.cloud.key_pairs.new :name => "turtles"
    keypair.save
  end
  File.open(t.name, 'w') do |f|
    f.write(keypair.private_key)
  end
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
  [:micro_bosh_cloud_setup, micro_bosh_deploy_config, turtles_pk] do

  cd deploy_dir do
    sh "bosh -n micro deployment micro"
    sh "bosh -n micro deploy ami-7ac7494a"
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
