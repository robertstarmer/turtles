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


module Turtles
  module Infrastructure
    module Openstack
      class << self; attr_accessor :openstack; end

      require 'fog'

      def to_hash
        {:name => self.name.split('::').last.downcase,
         :cloud_properties => {
            :instance_type => 'm1.small',  # todo gather from flavors
            :key_name      => 'deployer',  # todo gather from key_pairs
         },
         :static_addresses => self.detect[:addresses].select { |a| not a.fixed_ip },
         :networks => {
            :default => {:name => 'private',
                         :type => 'dynamic',
                         :cloud_properties => {
                           :security_groups => ['default']}},
            :static => {:name => 'public',
                        :type => 'vip',
                        :cloud_properties => {
                          :security_groups => ['default']
                      }}}}
      end

      def allocate_address
        floating_ip = self.openstack.allocate_address.body
        floating_ip = Fog::Compute::OpenStack::Address.new(attributes=floating_ip["floating_ip"])
        floating_ip
      end

      def setup(credentials=nil, force=false)
        credentials ||= {} 

        self.openstack = nil if force
        self.openstack ||= Fog::Compute.new(:provider => 'OpenStack',
                                            :openstack_auth_url => credentials[:os_auth_url],
                                            :openstack_username => credentials[:os_username],
                                            :openstack_api_key  => credentials[:os_password],
                                            :openstack_tenant   => credentials[:os_tenant])
      end

      def setup?
        self.openstack && true
      end

      def detect(credentials=nil)
        setup(credentials)

        res = {:nodes   => Openstack::openstack.servers,
               :flavors => Openstack::openstack.flavors,
               :images  => Openstack::openstack.images,
               :volumes => Openstack::openstack.volumes,
               :key_pairs => Openstack::openstack.key_pairs,
               :addresses => Openstack::openstack.addresses,
              }
      end

      module_function :detect, :setup, :to_hash, :allocate_address, :setup?
    end
  end
end
