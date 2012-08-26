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


COMMANDS = {}


class Command < Object
  def initialize(name, &block)
    instance_eval &block

    COMMANDS[name] = self
  end

  def usage(msg=nil)
    @usage ||= msg
    @usage
  end
end


def prepare_commands
  command :deploy do
    usage "Deploy microbosh instance and then cloudfoundry"
  end
end

def command name, &block
  Command.new(name, &block)
end

def run(args)
  raise Exception unless command = COMMANDS[args.shift]

  begin
    command.despatch(args)
  rescue ArityError
    puts command.usage
    puts
    exit(1)
  end
end
