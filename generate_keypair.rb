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


def random(length=8)
  (36 ** (length-1) + rand(36 ** length)).to_s(36)
end

if __FILE__ == $0
  name = ARGV.shift or "bosh-#{random}"

  creds = {}
  unless File.exists?(File.expand_path("~/.fog"))
    creds = get_openstack_credentials
  end

  conn = Fog::Compute.new({:provider => "OpenStack"}.update(creds))

  keypath = File.expand_path("~/.ssh/#{name}.pem")
  keypair = conn.key_pairs.create(:name => name)
  keypair.write(keypath)

  FileUtils.chown 'vcap', 'vcap', keypath
end
