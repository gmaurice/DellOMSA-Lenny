#!/bin/bash

# This script installs Dell OMSA 6.4 (latest version when writing these words) on Debian Lenny. The hack consists on using Debian Squeeze bootstrap, for service launching and om* commands using. 
#
# Based on this post : http://gloriousoblivion.blogspot.com/2010/12/running-dell-omsa-63-under-debian-lenny.html
# 
# Author : Germain MAURICE <ger***.***ice@linkfluence.net>
#
#####################################
# 2011/02/22 : Germain MAURICE : first version (specific to amd64)
# 2011/02/24 : Modified by: Mukarram Syed for i386
# 2011/02/25 : Germain MAURICE : keeped apt-get to be more compliant and autodetect achitecture of Debian installation
#####################################

echo "Be sure you've purge or removed any previous installation of Dell OMSA, via sara.nl by example. Continue ? type 'Yes' to continue."
read ASW
if [[ $ASW != "Yes" ]]; then
	exit;
fi

ARCH=$(apt-config dump | sed -nr 's/APT::Architecture \"(\S+)\";/\1/p');

####
#    For more information please refer to : http://linux.dell.com/repo/community/deb/latest/
#    and to the linux-poweredge mailing list https://lists.us.dell.com/mailman/listinfo/linux-poweredge
#
#   Available packages :
#    srvadmin-all:Install all OMSA components
#    srvadmin-base:Install only base OMSA, no web server
#    srvadmin-rac4:Install components to manage the Dell Remote Access Card 4
#    srvadmin-rac5:Install components to manage the Dell Remote Access Card 5
#    srvadmin-idrac:Install components to manage iDRAC
#    srvadmin-webserver:Install Web Interface
#    srvadmin-storageservices:Install RAID Management 
#
## Specify here what packages you want to install
OMSA_PACKAGES="srvadmin-base srvadmin-storageservices srvadmin-rac5";



cat <<EOF > /etc/apt/sources.list.d/debian.squeeze.sources.list
deb http://mirrors.kernel.org/debian/ squeeze main non-free contrib
deb http://security.debian.org/ squeeze/updates main non-free contrib
EOF

apt-get update

apt-get install debootstrap

debootstrap --arch $ARCH squeeze /srv/squeeze-$ARCH

cp /etc/{hosts,passwd,resolv.conf,group,shadow,gshadow} /srv/squeeze-$ARCH/etc/

cp /etc/fstab{,.dist}

cat <<EOF >> /etc/fstab
/proc /srv/squeeze-$ARCH/proc none rw,rbind 0 0
/sys /srv/squeeze-$ARCH/sys none rw,rbind 0 0
/dev /srv/squeeze-$ARCH/dev none rw,rbind 0 0
/tmp /srv/squeeze-$ARCH/tmp none rw,bind 0 0
/lib/modules /srv/squeeze-$ARCH/lib/modules none rw,bind 0 0
EOF

mount -a

cat <<EOF > /srv/squeeze-$ARCH/etc/apt/sources.list
deb http://mirrors.kernel.org/debian/ squeeze main non-free contrib
deb http://security.debian.org/ squeeze/updates main non-free contrib
EOF

chroot /srv/squeeze-$ARCH apt-get update
chroot /srv/squeeze-$ARCH apt-get -f install
chroot /srv/squeeze-$ARCH apt-get upgrade

echo 'deb http://linux.dell.com/repo/community/deb/latest /' > /srv/squeeze-$ARCH/etc/apt/sources.list.d/linux.dell.com.sources.list 

chroot /srv/squeeze-$ARCH apt-get update
chroot /srv/squeeze-$ARCH apt-get install $OMSA_PACKAGES
## Activate dataeng service at runlevel 2 if you want launched at the next boot (dataeng LSB header has to be fixed, http://lists.us.dell.com/pipermail/linux-poweredge/2011-February/044314.html)
chroot /srv/squeeze-$ARCH update-rc.d dataeng enable 2
chroot /srv/squeeze-$ARCH service dataeng start
chroot /srv/squeeze-$ARCH /opt/dell/srvadmin/sbin/omreport chassis info

cat <<EOF > /usr/local/bin/squeeze-$ARCH
#!/bin/bash
exec chroot /srv/squeeze-$ARCH "\$0" "\$@"
EOF

chmod 755 /usr/local/bin/squeeze-$ARCH
ln -s /usr/local/bin/squeeze-$ARCH /etc/init.d/dataeng
ln -s /usr/local/bin/squeeze-$ARCH /etc/init.d/instsvcdrv

# Adjust lenny LSB scripts to chrooted Dell OMSA init.d scripts, they have to be in the same path to be launched at boot
chroot /srv/squeeze-$ARCH/ find /etc/rc?.d/ -name "*dataeng" | xargs -ipath ln -s /etc/init.d/dataeng path
chroot /srv/squeeze-$ARCH/ find /etc/rc?.d/ -name "*fancontrol" | xargs -ipath ln -s /etc/init.d/fancontrol path

mkdir -p /opt/dell/srvadmin/bin
ln -s /usr/local/bin/squeeze-$ARCH /opt/dell/srvadmin/bin/omreport
ln -s /usr/local/bin/squeeze-$ARCH /opt/dell/srvadmin/bin/omconfig
ln -s /usr/local/bin/squeeze-$ARCH /opt/dell/srvadmin/bin/omshell

## Remove Squeeze repository from your Debian Lenny installation which may cause your system broken if you make some upgrade via apt*.
rm /etc/apt/sources.list.d/debian.squeeze.sources.list
apt-get update

# This could display to you some basic information about your hardware
omreport chassis info