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



PHASE_ONE_CONFIG=<<EOF
--- 
name: cloudfoundry
version: 96.1-dev
director_uuid: <%= config[:uuid] %>

release:
    name: cloudfoundry
    version: 96.1-dev

compilation:
  workers: 2
  network: private
  cloud_properties:
    instance_type: m1.small
    key_name: deployer

update:
  canaries: 1
  canary_watch_time: 3000-90000
  update_watch_time: 3000-90000
  max_in_flight: 1
  max_errors: 1 

networks:
- name: private
  type: dynamic
  cloud_properties:
    security_groups:
    - default
- name: public 
  type: vip
  cloud_properties:
    security_groups:
       - default

resource_pools:
- name: dea
  network: private
  size: 4
  stemcell: 
    name: micro-bosh-stemcell
    version: 0.6.4
  cloud_properties: 
    instance_type: m1.small
    key_name: <%= config[:cloud][:properties][:openstack][:default_key_name] %>
  env: 
    bosh:
      password: <%= config[:env][:bosh][:password] %>
- name: infrastructure
  network: private
  size: 10
  stemcell: 
    name: micro-bosh-stemcell
    version: 0.6.4
  cloud_properties:
    instance_type: m1.small
    key_name: <%= config[:cloud][:properties][:openstack][:default_key_name] %>
  env: 
    bosh:
      password: <%= config[:env][:bosh][:password] %>

jobs:
- name: debian_nfs_server
  template: debian_nfs_server
  instances: 1
  resource_pool: infrastructure
  persistent_disk: 8192
  networks:
  - name: private
    default: 
    - dns
    - gateway
- name: ccdb_postgres
  template: ccdb_postgres
  instances: 1
  resource_pool: infrastructure
  persistent_disk: 8192
  networks: 
  - name: private
    default: 
    - dns
    - gateway
- name: vcap_redis
  template: vcap_redis
  instances: 1
  resource_pool: infrastructure
  networks: 
  - name: private
    default: 
    - dns
    - gateway

properties:
  domain: cf.pistoncloud.com

  env: {}

  networks:
    apps: private
    management: private

  nats:
    user: nats
    password: nats
    address: <%= config[:nats][:address] %>
    port: 4222

  ccdb:
    user: ccadmin
    password: <%= config[:ccdb][:password] %>
    address: 
    port: 5524
    pool_size: 10
    dbname: appcloud
    roles:
    - tag: admin
      name: ccadmin
      password: <%= config[:ccdb][:password]
    databases:
    - tag: cc
      name: appcloud

  vcap_redis:
    address: 172.29.3.33
    port: 5454
    password: <%= config[:redis][:password] %>
    maxmemory: 1000000000

  nfs_server:
    address: 
    network:
EOF

PHASE_TWO_CONFIG=<<EOF
--- 
name: cloudfoundry
version: 96.1-dev
director_uuid: <%= config[:uuid] %>

release:
    name: cloudfoundry
    version: 96.1-dev

compilation:
  workers: 2
  network: private
  cloud_properties:
    instance_type: m1.small
    key_name: deployer

update:
  canaries: 1
  canary_watch_time: 3000-90000
  update_watch_time: 3000-90000
  max_in_flight: 1
  max_errors: 1 

networks:
- name: private
  type: dynamic
  cloud_properties:
    security_groups:
    - default
- name: public 
  type: vip
  cloud_properties:
    security_groups:
       - default

resource_pools:
- name: dea
  network: private
  size: 4
  stemcell: 
    name: micro-bosh-stemcell
    version: 0.6.4
  cloud_properties: 
    instance_type: m1.small
    key_name: <%= config[:cloud][:properties][:openstack][:default_key_name] %>
  env: 
    bosh:
      password: <%= config[:env][:bosh][:password] %>
- name: infrastructure
  network: private
  size: 10
  stemcell: 
    name: micro-bosh-stemcell
    version: 0.6.4
  cloud_properties:
    instance_type: m1.small
    key_name: <%= config[:cloud][:properties][:openstack][:default_key_name] %>
  env: 
    bosh:
      password: <%= config[:env][:bosh][:password] %>

jobs:
- name: debian_nfs_server
  template: debian_nfs_server
  instances: 1
  resource_pool: infrastructure
  persistent_disk: 8192
  networks:
  - name: private
    default: 
    - dns
    - gateway
- name: cloud_controller
  template: cloud_controller
  instances: 2
  resource_pool: infrastructure
  networks: 
  - name: private
    default: 
    - dns
    - gateway
- name: dea
  template: dea
  instances: 4
  resource_pool: dea
  networks: 
  - name: private
    default: 
    - dns
    - gateway
- name: router
  template: router
  instances: 1
  resource_pool: infrastructure
  networks: 
  - name: private
    default: 
    - dns
    - gateway
  - name: public
    static_ips: 
    - <%= config[:router_ip] %>
- name: stager
  template: stager
  instances: 1
  resource_pool: infrastructure
  networks: 
  - name: private
    default: 
    - dns
    - gateway
- name: ccdb_postgres
  template: ccdb_postgres
  instances: 1
  resource_pool: infrastructure
  persistent_disk: 8192
  networks: 
  - name: private
    default: 
    - dns
    - gateway
- name: vcap_redis
  template: vcap_redis
  instances: 1
  resource_pool: infrastructure
  networks: 
  - name: private
    default: 
    - dns
    - gateway
- name: health_manager
  template: health_manager
  instances: 1
  resource_pool: infrastructure
  networks: 
  - name: private
    default: 
    - dns
    - gateway

properties:
  domain: <%= config[:domain] %>

  env: {}

  networks:
    apps: private
    management: private

  nats:
    user: nats
    password: nats
    address: <%= config[:nats][:address] %>
    port: 4222

  cc:
    srv_api_uri: <%= "api.#{config[:domain]}" %>
    external_uri: <%= config[:domain] %>
    password: aaauuLaap44jadlas2l312lk
    token: aaaf4eaa8c1758f66d5cb7adcb24adb9d7
    use_nginx: true
    new_stager_percent: 25
    new_stager_email_regexp: '.*@pistoncloud.com.com'
    staging_upload_user: stager
    staging_upload_password: <%= config[:stager_pass] or 'stager' %>
    allow_registration: true
    uaa:
      enabled: false
    admins:
    - <%= config[:admin_email] %>

  stager:
    max_staging_duration: 120
    max_active_tasks: 20
    queues:
    - staging

  ccdb:
    user: ccadmin
    password: <%= config[:ccdb][:password] %>
    address: <%= config[:ccdb][:address] %>
    port: 5524
    pool_size: 10
    dbname: appcloud
    roles:
    - tag: admin
      name: ccadmin
      password: <%= config[:ccdb][:password]
    databases:
    - tag: cc
      name: appcloud

  vcap_redis:
    address: <%= config[:redis][:address] %>
    port: 5454
    password: <%= config[:redis][:password] %>
    maxmemory: 1000000000

  dea:
    max_memory: 1024

  nfs_server:
    address: <%= config[:nfs][:address] %>
    network: <%= config[:nfs][:network] %>

  router:
    status:
      port: 8080
      user: router
      password: <%= config[:router][:password] %>

  uaa:
    cc:
      token_secret: FAKEFAKEFAKE
      client_secret: $2a$08$dahioBqSkqa1AbLvaqkLoe5W0aOPN3Ia9W0xkeB926G.AZJhq1SsK
    batch:
      username: FAKEFAKEFAKE
      password: FAKEFAKEFAKE
EOF

def random(length=8)
  (36 ** (length-1) + rand(36 ** length)).to_s(36)
end

def build_config(uuid, host)
  bosh_config = YAML::load(File.open("/var/vcap/deployments/microbosh-openstack/micro_bosh.yml"))
  config = {:uuid => host,
            :nats => {:address => host,}, 
            :ccdb => {:password => random(length=16),}
            :redis => {:password => random(length=16),}}

  config.update(bosh_config)
end


def configure_phase_one(config)
end

def configure_phase_two
end


if __FILE__ == $0
  case ARGV.shift
  when /phase-1/ then 
    director_uuid  = ARGV.shift
    bosh_host = ARGV.shift

    raise "Need a bosh host and uuid" unless bosh_host and director_uuid

    config = build_config(director_uuid, host)
    configure_phase_one(config)

  when /phase-2/ then puts "PHASE2"
  else
    usage=<<-USAGE
      Usage: #{$0} command <arguments>
        phase-1:
          arguments -> director_uuid
        phase-2:
          arguments -> router_ip
    USAGE
    puts usage
  end
end
