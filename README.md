# script_composed-vmd_sh
This is just some tooling to compose up my VM's. It's opinionated to my 
environment, but may be useful for others.

# Introduction
I use OpenBSD, and VMD, to host vm's - primarmily OpenBSd themselves. I
cross reference details of the vm's, and how I apply them to my
environment, which allows me to quickly deploy/manage.

# DEBUG
Will effectively dry-run the code. All of the calls to child functions
will be echo only. A temp file is created for the vm configuration and
validation step in /tmp. The system is not changed otherwise.

SOME features may not work at all if not run as SUDO in debug, such as
reading vmd config files with ACL that are not permissive of user.

# DNSDOMAINNAME
I use the DNSDOMAINNAME in the description, but also name, of the VM.
This is because I may have the same, or similarly named, VM's on my
networks. "mirror" is not descriptive. But "mirror.my.network", with
my.network unique to a particular Network/VLAN, is.

# IP
I use the final dotted-decimal 8 bits to help define the UID of the VM
owner. This is not always useful, but the thought process of considering
it often still useful.

Making this decision up front also ensures I reserve a static DHCP
record.

# MACPREFIX
I also use the MAC address to help describe the VM. This ensures I do
not have any rogue/unexpected devices on the networks.

# MEMORY
Self explanitory. Most of my VM's, including Linux, run on 512MB.

# NETCONF
I separate my VMD network configuration to an indepdendent file. To
ensure that the configurations generated from this are valid, I leverage
the config test -n flag of vnd. This allows the script to verify that
the uplink exists.

# SWITCH
This is the uplink which is verified with the above netconf.

# SUBNET
This is also part of the UID of the owner of the VM. The final
convention is;
<VMDUID><SUBNETID><IP>
eg; 10730130
Would be for the vm hosted on the VLAN30, with IP ending 130. Bad.. I
know.

# Prerequisites:
Eventually it should run with a _vmd_manager account, which has
appropriate doas permissions - but for now that feature is incomplete.

Privilege separation is still built in, which will leverage root for
some functions, and the created user for each vm wherever possible.
