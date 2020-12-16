#!/bin/ksh

set -e
umask 0022
export PATH=/usr/bin:/bin:/usr/sbin:/sbin

# Some Defaults
# This is the name of our default disk image.
DEFAULT_DISK=root.img
DEFAULT_DISK_SIZE=8
# This is our default boot.
DEFAULT_BOOT=/bsd.rd

# These are some static values.
# 107 = _vmd [gu]id.
STATIC_PREFIX_UID=107
STATIC_PREFIX_GID=107
# _vmd_ to make vm machine owners obvious.
STATIC_PREFIX_USERNAME=_vmd_

err () {
	echo "${0##*/}: ${1}" 1>&2
	if [[ $DEBUG -eq 1 ]]; then
		return 0
	else
  	return ${2:-1}
	fi
}

usage () {
	echo "${0##*/} [-D DEBUG] \
[-d DNSDOMAINNAME] \
[-i IP] \
[-M MACPREFIX] \
[-m MEMORY(MB)] \
[-N NETCONF File] \
[-S SWITCH] \
[-s SUBNET] \
name" 1>&2
	echo "	-D	DEBUG / DRY RUN"
	echo "	-d	DNSDOMAINNAME					example.com"
	echo "	-i	IP (32)						123"
	echo "	-M	MACPREFIX						AAAAAAA[###]"
	echo "	-m	MEMORY (MB)					1024"
	echo "	-N	NETCONF File				/etc/vm.conf"
	echo "				Should contain the name of your switch.."
	echo "	-S	SWITCH (UPLINK)			uplink-official"
	echo "	-s	SUBNET (24)				20"
	return 1
}

privsep () {
	local _rc=0 _user=_vmd_manager

	if [[ $1 == -u ]]; then
		_user=$2;
		shift 2;
	fi
  
	if [[ $DEBUG -eq 1 ]]; then
		echo "DEBUG: su -s /bin/sh ${_user} -c '$@'"
	else
	  eval su -s /bin/sh ${_user} -c "'$@'" || _rc=$?
	fi

	return ${_rc}
}

optargstring="Dd:i:M:m:N:S:s:"

while getopts ${optargstring} arg; do
	case ${arg} in
	D)
		DEBUG=1
		;;
	d)
		INPUT_DOMAIN=${OPTARG}
		;;
	i)
		INPUT_IP="${OPTARG}"
		;;
	M)
		INPUT_MACPREFIX="${OPTARG}"
		;;
	m)
		INPUT_MEMORY="${OPTARG}"
		;;
	N)
		INPUT_NETCONFIG="${OPTARG}"
		;;
	S)
		INPUT_SWITCH="${OPTARG}"
		;;
	s)
		INPUT_SUBNET="${OPTARG}"
		;;
	*)
		usage
		;;
	esac
done

if [[ $DEBUG -eq 1 ]]; then
	shift 15
else
	shift 14
fi

(($(id -u) != 0)) && err "root privilege is required."

echo $#
case $# in
  0) usage;;
	1) INPUT_NAME=$1;;
	*) usage;;
esac

FINAL_USERNAME=$STATIC_PREFIX_USERNAME$INPUT_NAME

# Check this username does not already exist.
if [[ -d /home/$FINAL_USERNAME ]]; then
	err "A vm of this name already exists."
fi

FINAL_ID=$STATIC_PREFIX_UID$INPUT_SUBNET$INPUT_IP

# Check this UID does not already exist.
if [[ $(grep -i ${FINAL_ID} /etc/passwd | wc -l) -eq 1 ]]; then
	err "A prefix, subnet, and ip, for this host already exist.
	${FINAL_ID}."
fi

FINAL_SWITCH=$INPUT_SWITCH
if [[ $(grep -i ${FINAL_SWITCH} ${INPUT_NETCONFIG} | \
	wc -l) -ne 1 ]]; then
	err "A switch with this name does not exist."
fi

FINAL_FQDN="${INPUT_NAME}.${INPUT_DOMAIN}"
FINAL_MEMORY="${INPUT_MEMORY}M"
FINAL_DESCRIPTION="User for ${FINAL_FQDN} VM." 
FINAL_MACADDRESS="${INPUT_MACPREFIX}${INPUT_IP}"

# Add the necessary user.
privsep -u root useradd \
  -G vmdusers \
  -L daemon \
  -m \
  -s /sbin/nologin \
  -u $FINAL_ID \
  $FINAL_USERNAME

# As the user, create the VM Disk.
privsep -u $FINAL_USERNAME vmctl \
	create -s "${DEFAULT_DISK_SIZE}G" \
	/home/$FINAL_USERNAME/$DEFAULT_DISK

	CONFIG_TEMPLATE="vm \"$FINAL_FQDN\" {\n \
\tdisable\n \
\towner $FINAL_USERNAME\n \
\tmemory $FINAL_MEMORY\n \
\tboot \"/bsd.rd\"\n \
\tdisk \"/home/$FINAL_USERNAME/$DEFAULT_DISK\"\n \
\tinterface tap {\n \
\t\tswitch \"$FINAL_SWITCH\"\n \
\t\tlladdr $FINAL_MACADDRESS\n \
\t}\n}"

echo -e $CONFIG_TEMPLATE
echo $CONFIG_TEMPLATE > "/tmp/${FINAL_FQDN}.conf"

# We do not privsep this function yet...
# now we do.. but should we? this is a bit like running echo, cat,
# grep..
if privsep -u $FINAL_USERNAME vmd \
	-f /tmp/${FINAL_FQDN}.conf -n; then
  privsep -u root install -F -o 0 -g 0 -m 0750 /tmp/${FINAL_FQDN}.conf \
		/etc/vm.d/machine/${FINAL_FQDN}.conf
else
	err "VM Configuratoin failed vmd config test.";
fi

