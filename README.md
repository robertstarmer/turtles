Turtles
=======

Turtles is an installer for microbosh and cloudfoundry on OpenStack.
It's being converted to match the new CloudFoundry bootstrap approach.

Using Turtles
=============

Starting out assumes a fresh OpenStack environment with a single bootstrap VM. Turtles was
developed assuming an Ubuntu machine. Bootstrapping (inception) would start with these commands:

  apt-get update
  apt-get install git ruby1.9.1 -y
  git clone https://github.com/piston/turtles.git
  ln -s ~/turtles/bin/turtles /usr/local/bin/turtles
  turtles prepare

This installs all dependencies necessary to continue. Before starting, we have to set some
configuration:

  turtles config

This will open the configuration file, which will require some changes. In fact, almost all fields.
The curious one is the admin key, which is used to manage stemcell images in Swift. Speaking of which,
you can either grab pre-existing stemcells images or generate them. Generating takes several hours, but
you can start the process of building both stemcells and uploading them to Swift with:

  turtles stemcells

I'd recommend against this if you can get recent stemcells. They'll need to be placed in Swift at:

  http://swift_server/turtles/bosh-stemcell.tgz
  http://swift_server/turtles/micro-bosh-stemcell.tgz

Turtles will expect them to be there before you start deploying:

  turtles deploy-bosh

This will create a keypair with OpenStack and use it for the rest of the process. There is an option
to use your own key and keyname by providing them as arguments to `turtles deploy-bosh`. In any case,
from here it's an autopilot until micro BOSH is running. 

*It should be noted that a full BOSH deployment is not deployed. Only a micro BOSH deployment, since that
is all that's necessary to get a running Cloud Foundry environment.*

Once it's finished, it'll run `bosh status` for you, showing you that BOSH is running. You don't need
this information to continue. From here, just run:

  turtles deploy-cf

This will take even longer. Because of the complexity of this orchestration and the occasional ... instability
of the OpenStack environment, something might fail. The CF deployment script will try to get around this by
running cloud check and automatically repairing, then continuing to deploy again, which will continue where left
off. If after two tries at this and it still fails, it will delete the deployment and start over. This then is
performed in an infinite loop, so it is fairly determined.

Turtles Architecture
====================
The `turtles` command is a simple Ruby script that mostly wraps a central Rakefile. Developers may want to 
use the Rakefile directly. In fact, when something fails that can't be corrected, you must use `rake reset`
to clear the working directory. Which brings us to some assumptions:

 * turtles is installed to ~/turtles
 * turtles uses ~/work as a workspace to use BOSH and build artifacts

You must cd into ~/turtles to use the rake commands, which will operate on ~/work. Most of the heavy lifting
is done in the Rakefile. There is a single component in lib under a Turtles module that includes one piece of
functionality that had to be developed other than the meta-orchestration: allocating named IPs. In order to
configure BOSH and CF, they must be given static IPs. So IPs are allocated by names stored in a local file
on the bootstrap machine. This is important to know as it is a peculiar piece of state that could cause 
problems if not acknowledged. 

In reading the code, you may notice that there are some provisions that make it seem to support AWS as well
as OpenStack. Turtles was originally developed against AWS and then made to run on OpenStack, leaving the AWS
code in. It might not work. In fact, because of major changes in CF and BOSH, it's possible Turtles has a number
of bugs. However, the general architecture isn't likely to have changed too much, so hopefully it shouldn't be much 
work to fix anything that comes up.

There are a few other historical artifacts, for example, the bosh_openstack_cpi gem that's included in Turtles.
This is because changes were made upstream to the CPI but they were not released to RubyGems at the time. By now
the OpenStack CPI is likely several versions newer and I hear even has a new maintainer. 