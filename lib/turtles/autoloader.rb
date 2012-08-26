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
  module Autoloader
    def self.included(base)
      base.extend(LazyMethods)

      base.setup
    end

    module LazyMethods
      class << attr_accessor :lazy; end

      def const_missing(mod)
        load self.lazy[mod]
        return const_get(mod)
      end

      def lazyload(mod)
        return self.const_get(mod)
      end

      def setup
        self.lazy = {} if not self.lazy

        mod_name = self.name.split('::').last

        Dir[File.join(File.dirname(__FILE__), mod_name.downcase, '/') + '*.rb'].each do |mod_path|
          mod_obj = File.basename(mod_path, '.rb').capitalize.to_sym

          self.lazy ||= {}
          self.lazy[mod_obj] = mod_path
        end
      end
    end
  end
end
