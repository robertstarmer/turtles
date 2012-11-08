#!/usr/bin/env bash
apt-get update
apt-get install build-essential libsqlite3-dev curl rsync git-core \
libmysqlclient-dev libxml2-dev libxslt-dev libpq-dev libsqlite3-dev \
genisoimage ruby1.9.1-dev rubygems ruby-bundler rake debootstrap \
kpartx python-setuptools qemu -y

update-alternatives --set ruby /usr/bin/ruby1.9.1
update-alternatives --set gem /usr/bin/gem1.9.1

echo "install: --no-ri --no-rdoc" > /etc/gemrc
echo "update: --no-ri --no-rdoc" >> /etc/gemrc

gem install bosh_deployer
gem install fog

easy_install pip
