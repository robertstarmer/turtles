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

KEYNAME = ENV['KEYNAME'].to_s.empty? ? "turtles" : ENV['KEYNAME']
KEYFILE = ENV['KEYFILE'].to_s

def provider; Turtles.config['cloud'][:provider]; end

# Path helpers
def data_file(filename, use_provider=false)
  File.join([TURTLES_DIR, 'data', use_provider ? provider() : nil, filename].compact)
end
def turtles_path(*parts);   File.join(parts.unshift(TURTLES_DIR)); end
def work_path(*parts);      File.join(parts.unshift(WORK_DIR)); end

# Paths
turtles_config            = File.expand_path("~/.turtles")
turtles_pk                = work_path('turtles.pem')
deploy_dir                = work_path('deployments')
bosh_release              = work_path('bosh-release.tgz')
bosh_checkout             = work_path('bosh')
micro_bosh_deploy_dir     = work_path('deployments', 'micro')
micro_bosh_deploy_config  = work_path('deployments', 'micro', 'micro_bosh.yml')
micro_bosh_stemcell       = work_path('micro-bosh-stemcell.tgz')
bosh_stemcell             = work_path('bosh-stemcell.tgz')

directory WORK_DIR
directory deploy_dir
directory micro_bosh_deploy_dir

# Other helpers

def swift(*args, &block)
  auth_url = Turtles.config['cloud'][:openstack_auth_url]
  admin_key = Turtles.config['cloud'][:openstack_admin_key]
  sh "swift -A #{auth_url} -V 2.0 -U admin:admin -K #{admin_key} #{args.join(' ')}", &block
end

def bosh_uuid
  `bosh status | grep UUID`.strip.split.last
end

def exist(t)
  if File.exist? t.name
    touch t.name
    true
  else
    false
  end
end

# TASKS

file bosh_release => WORK_DIR do |t|
  next if exist t
  cd WORK_DIR
  rm_rf 'bosh-release'
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

file bosh_checkout => WORK_DIR do |t|
  next if exist t
  cd WORK_DIR
  rm_rf 'bosh'
  sh 'git clone git://github.com/cloudfoundry/bosh.git'
end


file micro_bosh_stemcell => [bosh_checkout, bosh_release, WORK_DIR] do |t|
  next if exist t
  cd WORK_DIR
  cd 'bosh/agent' do
    sh 'bundle install --without=development test'
    manifest = work_path('bosh-release', 'micro', "#{provider}.yml")
    sh "rake stemcell2:micro[#{provider},#{manifest},#{bosh_release}]"
    stemcell = `find /var/tmp -name micro-bosh-stemcell*`.strip
    mv stemcell, t.name
  end
end

desc "Build micro bosh stemcell"
task :micro_stemcell => micro_bosh_stemcell

file bosh_stemcell => [bosh_checkout, WORK_DIR] do |t|
  next if exist t
  cd WORK_DIR
  cd 'bosh/agent' do
    sh 'bundle install --without=development test'
    sh "rake stemcell2:basic[#{provider}]"
    stemcell = `find /var/tmp -name bosh-stemcell*`.strip
    mv stemcell, t.name
  end
end

desc "Build basic stemcell"
task :stemcell => bosh_stemcell

file micro_bosh_deploy_config => [micro_bosh_deploy_dir, turtles_pk, turtles_config] do |t|
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
  keyname = KEYNAME
  template = ERB.new(File.read(data_file('micro_bosh_deploy.yml.erb', true)))
  File.open(t.name, 'w') do |f|
    f.write(template.result(binding))
  end
end

file turtles_pk => turtles_config do |t|
  next if exist t
  # runs if no pk file, so always recreate keypair
  keypair = Turtles.cloud.key_pairs.get(KEYNAME)
  keypair.destroy rescue nil if keypair # rescue because fog expects 200 but we get 202
  if KEYFILE.empty?
    keypair = Turtles.cloud.key_pairs.new :name => KEYNAME
    keypair.save
    keypair.write(t.name)
  else
    public_key = File.read(KEYFILE)
    keypair = Turtles.cloud.key_pairs.new :name => KEYNAME, :public_key => private_key
    keypair.save
    cp KEYFILE, t.name
  end
end

task :micro_bosh_cloud_setup => turtles_config do
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
    group.save rescue nil # for some reason this errors out but makes it anyway
    # too many ports to be specific yet
    if Turtles.cloud.class.to_s.include? "OpenStack"
      group.create_security_group_rule(1, 65535)
    else
      group.authorize_port_range(0..65535)
    end
  end
end

desc "Deploy micro bosh"
task :micro_bosh_deploy =>
  [:micro_bosh_cloud_setup,
   micro_bosh_deploy_config,
   turtles_pk,
   turtles_config,
   micro_bosh_stemcell,
   bosh_stemcell] do

  cd deploy_dir do
    rm_rf "bosh-deployments.yml"
    sh "bosh -n micro deployment micro"
    sh "bosh -n micro deploy #{micro_bosh_stemcell}"
    sh "bosh -n target http://#{Turtles::NamedIP.get_ip("micro-bosh")}:25555"
    sh "bosh -n login admin admin"
    sh "bosh -n upload stemcell #{bosh_stemcell}"
    sh "bosh status"
  end
end

desc "Deploy wordpress sample"
task :sample_deploy => WORK_DIR do
  cd WORK_DIR
  rm_rf 'bosh-sample-release'
  sh 'git clone git://github.com/cloudfoundry/bosh-sample-release.git'
  cd 'bosh-sample-release' do
    sh "bosh -n upload release releases/wordpress-1.yml" 
    security_group = "turtles-bosh-micro"
    director_uuid = bosh_uuid
    mysql_ip = Turtles::NamedIP.get_ip("sample-mysql")
    wordpress_ip = Turtles::NamedIP.get_ip("sample-wordpress")
    nginx_ip = Turtles::NamedIP.get_ip("sample-nginx")
    nfs_ip = Turtles::NamedIP.get_ip("sample-nfs")
    template = ERB.new(File.read(data_file('sample_deploy.yml.erb', true)))
    File.open('wordpress-openstack.yml', 'w') do |f|
      f.write(template.result(binding))
    end
    sh "bosh -n deployment wordpress-openstack.yml"
    sh "bosh -n deploy"
  end
end

task :sample_delete do
  sh "bosh -n delete deployment wordpress"
  sh "bosh -n delete release wordpress"
end

desc "Delete micro bosh"
task :micro_bosh_delete do
  cd deploy_dir do
    sh "bosh -n micro delete"
  end
end

desc "Reset work directory"
task :reset do
  rm_rf WORK_DIR
end

task :swift do
  sh "pip install #{turtles_path('pkgs', 'swift.tar.gz')}"
end

desc "Download stemcells from swift"
task :download_stemcells => [:swift, WORK_DIR] do
  cd WORK_DIR
  swift 'download', 'turtles', 'bosh-stemcell.tgz'
  swift 'download', 'turtles', 'micro-bosh-stemcell.tgz'
end

desc "Upload stemcells to swift"
task :upload_stemcells => [:swift, WORK_DIR] do
  cd WORK_DIR
  ['bosh-stemcell.tgz', 'micro-bosh-stemcell.tgz'].each do |f|
    if File.exist? f
      swift 'delete', 'turtles', f
      swift 'upload', 'turtles', f
    end
  end
end

task :install_fixed_cpi do
  # Ideally taken care of by inception script
  cd turtles_path('pkgs') do
    sh "gem install bosh_openstack_cpi-0.0.3.gem"
  end
end

task turtles_config do |t|
  next if exist t
  cp data_file('config_sample'), turtles_config
end

desc "Edit configuration"
task :config => turtles_config do
  sh "vi #{turtles_config}"
end
