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

require 'turtles/deployer/microbosh'

module Turtles
  module Deployer
    Transitions = {}
    def transition(state, new_state)
      Turtles::Deployer::Transitions[state] ||= [] << new_state
    end
    module_function :transition

    transition :de_novo, :microbosh
    transition :de_novo, :cloudfoundry
    transition :next, :cloudfoundry

    class Deployer
      def initialize(config, state=:de_novo, cpi=nil)
        @config = config
        @cpi = cpi || Turtles::Infrastructure::Interface.new(config)
        @state = state
      end

      def next
        case @state
        when :de_novo
          self.class.send :include, Turtles::Deployer::Microbosh
        when :next
          # include Cloudfoundry
        end
      end

      def generate_config
        @microbosh_config = Turtles::Configurator::generate(@config, key=k
      end

      def transition(state, &block)
        raise StateTransitionError unless @transitions[@state].include? state

        instance_eval &block
      end
    end

  end

  def Deployer(config)
    Turtles::Deployer::Deployer.new(config)
  end

  module_function :Deployer
end
