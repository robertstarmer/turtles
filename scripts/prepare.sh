apt-get update
apt-get install build-essential libsqlite3-dev curl rsync git-core \
libmysqlclient-dev libxml2-dev libxslt-dev libpq-dev libsqlite3-dev \
genisoimage ruby1.9.1 rubygems ruby-bundler rake debootstrap kpartx -y

echo "install: --no-ri --no-rdoc" > /etc/gemrc
echo "update: --no-ri --no-rdoc" >> /etc/gemrc

gem install bosh_deployer
