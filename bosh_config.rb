#!/usr/bin/env ruby
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
require 'fog'
require 'highline/import'

def get_openstack_credentials
  os_auth_url = ask("Your OpenStack auth-url: ").to_s
  os_username = ask("Your OpenStack username: ").to_s
  os_tenant   = ask("Your OpenStack tenant: ").to_s
  os_api_key  = ask("Your OpenStack API key: ") { |q| q.echo = '*' }.to_s

  {:openstack_auth_url => os_auth_url,
   :openstack_username => os_username,
   :openstack_tenant   => os_tenant,
   :openstack_api_key  => os_api_key,}
end

OPENSTACK_MANIFEST=<<EOF
---
deployment: micro
release:
  name: micro
  version: 9
configuration_hash: {}
properties:
  micro: true
  domain: 'vcap.me'
  env:
  networks:
    apps: local
    management: local
  nats:
    user: nats
    password: 'nats'
    address: 127.0.0.1
    port: 4222
  redis:
    address: 127.0.0.1
    port: 25255
    password: redis
  postgres:
    user: postgres
    password: postgres
    address: 127.0.0.1
    port: 5432
    database: bosh
  blobstore:
    address: 127.0.0.1
    backend_port: 25251
    port: 25250
    director:
      user: director
      password: director
    agent:
      user: agent
      password: agent
  director:
    address: 127.0.0.1
    name: micro
    port: 25555
  openstack_registry:
    address: 127.0.0.1
    http:
      port: 25777
      user: admin
      password: admin 
    db:
      database: postgres://postgres:postgres@localhost/bosh
      max_connections: 32
      pool_timeout: 10
  hm:
    http:
      port: 25923
      user: hm
      password: hm
    loglevel: info
    director_account:
      user: admin
      password: admin
    intervals:
      poll_director: 60
      poll_grace_period: 30
      log_stats: 300
      analyze_agents: 60
      agent_timeout: 180
      rogue_agent_alert: 180
EOF


MICROBOSH=<<EOF
---
name: microbosh-openstack

env:
  bosh:
    password: <%= config[:bosh_password] %>

logging:
  level: DEBUG

network:
  type: dynamic

resources:
  persistent_disk: 4096
  cloud_properties:
    instance_type: m1.small

cloud:
  plugin: openstack
  properties:
    openstack:
      auth_url: <%= config[:openstack_auth_url] %>
      username: <%= config[:openstack_username] %>
      api_key:  <%= config[:openstack_api_key] %>
      tenant:   <%= config[:openstack_tenant] %>
      default_security_groups: ["default"]
      default_key_name: <%= config[:key][:name] %>
      private_key: <%= config[:key][:path] %>
    registry:
      endpoint: http://admin:admin@localhost:25889
      user: admin
      password: admin
EOF


def random(length=8)
  (36 ** (length-1) + rand(36 ** length)).to_s(36)
end

def write_build_manifest(config, out_path)
  FileUtils.mkdir_p(File.dirname(out_path))

  t = ERB.new(OPENSTACK_MANIFEST)
  File.open(out_path, 'w') do |f|
    f.write(t.result binding)
  end
end

def write_deployment_manifest(config, out_path)
  FileUtils.mkdir_p(File.dirname(out_path))

  t = ERB.new(MICROBOSH)
  puts t
  File.open(out_path, 'w') do |f|
    f.write(t.result binding)
  end
end

if __FILE__ == $0
  name = ARGV.shift
  name = File.basename(name, ".pem")

  creds = {}
  if File.exists?(File.expand_path("~/.fog"))
    creds = YAML::load(IO.read(File.expand_path("~/.fog")))
  else
    creds = get_openstack_credentials
  end

  # GENERATE micro_bosh.yml
  salted_password = `mkpasswd -m sha-512 "#{random(16)}"`.strip
  config = {:bosh_passsword => salted_password,
            :key => {:name => name,
                     :path => File.expand_path("~/.ssh/#{name}.pem")}}
  config.update(creds[:default])

  write_deployment_manifest(config, "/var/vcap/deployments/microbosh-openstack/micro_bosh.yml")
  write_build_manifest(config, "/var/vcap/manifests/openstack_micro.yml")
end
