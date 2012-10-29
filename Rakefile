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

deploy_dir = File.join([WORK_DIR, 'deployments'])
micro_bosh_deploy_dir = File.join([deploy_dir, 'micro'])
micro_bosh_deploy_config = File.join([micro_bosh_deploy_dir, 'micro_bosh.yml'])
micro_bosh_stemcell = File.join([WORK_DIR, 'micro-bosh-stemcell.tgz'])

directory WORK_DIR

file micro_bosh_stemcell => WORK_DIR do |t|
  cd WORK_DIR
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
      stemcell = `find /var/tmp -name micro-bosh-stemcell*`
      mv stemcell, t.name
    end
  end
end

directory deploy_dir
directory micro_bosh_deploy_dir

file micro_bosh_deploy_config => micro_bosh_deploy_dir do |t|
  ip = "50.112.243.192"
  aws_region = "us-west-2"
  access_key_id = "1TZ5G0RRE3RGFE0J4ZG2"
  secret_access_key = "7rG64c+Fq+DF8CUpFr8nkWPxJASxtOUrkmGOJLbf"
  template = ERB.new(File.read(data_file('micro_bosh_deploy.yml.erb', true)))
  File.open(t.name, 'w') do |f|
    f.write(template.result(binding))
  end
end

task :micro_bosh_deploy => micro_bosh_deploy_config do
  cd deploy_dir do
    sh "bosh -n micro deployment micro"
    sh "bosh -n micro deploy ami-7ac7494a"
  end
end

task :reset do
  rm_rf WORK_DIR
end
