require 'rubygems'
require 'fog'

module OpenStackAdapter
  def server_id; instance_id; end
  def public_ip; ip; end
end

def adapt_address(a)
  if Turtles.cloud.class.to_s.include? "OpenStack"
    a.extend(::OpenStackAdapter)
  end
  a
end

module Turtles

  class NamedIP

    def self.get_ip(name)
      all_ips = Turtles.cloud.addresses
      all_ips.collect {|a| adapt_address(a) }
      unassigned_ips = all_ips.select {|a| a.server_id.nil? }
      all_ips = all_ips.map(&:public_ip)
      unassigned_ips = unassigned_ips.map(&:public_ip)
      cache = Turtles.config['named_ips'] || {}
      if cache[name]
        if all_ips.include? cache[name]
          return cache[name]
        else
          cache.delete(name)
        end
      end
      unnamed_ips = unassigned_ips - cache.values
      if unnamed_ips.empty?
        address = adapt_address(Turtles.cloud.addresses.create)
        unnamed_ips << address.public_ip
      end
      cache[name] = unnamed_ips.shift
      Turtles.config['named_ips'] = cache
      Turtles.save_config()
      cache[name]
    end


  end
end
