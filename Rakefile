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

# find /var/tmp -name bosh-stemcell*

directory WORK_DIR

task :micro_bosh_stemcell => WORK_DIR do
  cd WORK_DIR
  sh 'git clone git://github.com/cloudfoundry/bosh-release.git'
  cd 'bosh-release' do
    sh "#{script_file('fix_gitmodules.sh')} .gitmodules"
    sh 'git submodule update --init'
    sh 'git stash'
    cp data_file('bosh-release-config.yml'), 'config/dev.yml' 
    sh 'bosh create release --with-tarball'
    tarball = Dir['dev_releases/*.tgz'].first
    cd 'src/bosh/agent' do
      sh 'bundle install --without=development test'
      manifest = data_file('micro_bosh_stemcell.yml', true)
      sh "rake stemcell2:micro[#{CLOUD_ARCH},#{manifest},#{tarball}]"
      # TODO: put it in a common place
    end
  end
end

task :micro_bosh_deploy do
  # TODO: use stemcell from above
end

task :reset do
  rm_rf WORK_DIR
end
