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
  module Configurator
    module Cloudfoundry
      RESOURCE_POOLS  = %w(dea infrastructure)
      STATIC_SERVICES = %w(debian_nfs server ccdb_postgres vcap_redis)
      PUBLIC_SERVICES = %w(router)
      SERVICES = %w(debian_nfs_server cloud_controller dea router stager
                    ccdb_postgres vcap_redis health_manager nats)

      class CloudFoundry < Object
        class StaticIPS
          def initialize(cpi, static_ips)
            @cpi = cpi
            @static_ips = Array(static_ips)
          end

          def static_ips(count=1)
            if count > @static_ips.length
              @static_ips += @cpi.allocate_addresses(count - static_ips.length)
            end

            @static_ips
          end

          def allocate(count)
            @static_ips += @cpi.allocate_addresses(count)
          end

          def reserve(count = 1)
            self.allocate(count - @static_ips.length) if count > @static_ips.length

            @static_ips.pop(count)
          end
        end

        @@name = 'cloudfoundry'
        @@version = 'x.x.x'

        def initialize(config)
          @config   = config
          @instances = Hash.new(1)  # Always at least one instance
          @impl     = config.delete(:impl)
          @bosh     = config.delete(:bosh)
          @stemcell = config.delete(:stemcell)
          @static_ips = StaticIPS.new(@impl, config[:static_addresses])
        end

        def networks
          @networks ||= @config[:networks]
          @networks
        end

        def resource_pools
          @resource_pools ||= Cloudfoundry::RESOURCE_POOLS.inject({}) do |pools, pool|
            pools[pool] = {:name => pool,
             :network => @config[:networks][:default][:name],
             :stemcell => @stemcell,
             :cloud_properties => @config[:cloud_properties],
             :env => @bosh
            }
            pools
          end

          @resource_pools.values
        end

        def jobs(period=:static)
          case period:
          when :static:
            services = STATIC_SERVICES
          when :all: 
            services = SERVICES
            @jobs = nil  # Unset to regenerate
          end

          @jobs ||= services.map do |job|
            selector = lambda { |p, n| p[:name] == n }

            instances = @instances[job]
            pool = self.resource_pools.select { |p| selector.call(p, job) }.first
            pool ||= self.resource_pools.select { |p| selector.call(p, 'infrastructure') }.first


            networks = [{:name => pool[:network],
                         :default => ['dns', 'gateway']}]

            if STATIC_SERVICES.include? job
              networks << {:name => self.networks[:static][:name],
                           :static_ips => @static_ips.reserve(instances).map {|a| a.ip }}
            end

            {:name => job,
             :template => job,
             :instances => 1,
             :resource_pool => pool[:name],
             :networks => networks}
          end

          @jobs
        end

        def properties
          {}
        end

        def to_hash
          {:name => @@name,
           :version => @@version,
           :director_uuid => 'foo',
           :compilation => {},
           :update => {},
           :networks => self.networks,
           :resource_pools => self.resource_pools,
           :jobs => self.jobs,
           :properties => self.properties,}
        end
      end

      def generate(config)
        return CloudFoundry.new(config)
      end

      module_function :generate,
    end
  end
end
