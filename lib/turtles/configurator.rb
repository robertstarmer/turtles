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

require 'yaml'

require 'turtles/autoloader'

def stringify_keys(hash)
  stringy_if_hash = lambda { |x| x.is_a?(Hash) ? stringify_keys(x) : x }

  hash.inject({}) do |h, (k, v)|
    h[k.to_s] = if v.is_a?(Array)
                  v.map { |n| stringy_if_hash.call(n) }
                else
                  stringy_if_hash.call(v)
                end
    h
  end
end

module Turtles
  module Configurator
    class ConfigurationError < Exception; end
    include Turtles::Autoloader

    def generate(config, key=nil)
      case key
      when :microbosh:
        Configurator::Microbosh.generate(config)
      when :cloudfoundry:
        Configurator::Cloudfoundry.generate(config)
      else:
        {:microbosh => Configurator::Microbosh.generate(config),
         :cloudfoundry => Configurator::Cloudfoundry.generate(config)}
      end
    end

    module_function :generate
  end
end
