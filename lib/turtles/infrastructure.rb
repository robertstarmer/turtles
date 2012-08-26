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


require 'turtles/autoloader'

module Turtles
  module Infrastructure
    include Turtles::Autoloader

    class IMPL
      attr_accessor :config, :impl

      def initialize(config)
        self.config = config
      end

      def impl
        @impl ||= Infrastructure.lazyload(self.config[:impl])
        @impl.setup self.config[:credentials] unless @impl.setup?
        @impl
      end

      def allocate_addresses(count=1)
        count.times.map { self.impl.allocate_address }
      end

      def detect
        self.impl.detect
      end

      def to_hash
        {:impl => self}.update(self.impl.to_hash)
      end
    end

    Interface = IMPL
  end
end

