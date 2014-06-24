#!/bin/bash
#This script is used to upgrade the Ubuntu Systems ansd PSG Firmware.
#This script upgrades Ubuntu OS from 10.10 to 12.04 LTS in three transacions
#That is: 10.10 to 11.04 to 11.10 to 12.04
#The time consumed by each Transation is 15 minutes
#The total time consumed for complte upgrade including PSG Firmware is 50 minutes.


main()
{
	CODENAME=$(lsb_release -cs)
	if [ $CODENAME = oneiric ]; then
	{

		/etc/init.d/pgxl-ctrl stop
		if [ -f ubuntu-12.04-i386.iso ]; then
                	mkdir /tmp/mou
                	mount -o loop ubuntu-12.04-i386.iso /tmp/mou/
                	/tmp/mou/cdromupgrade --without-network frontend=DistUpgradeViewText
			
        	  else
		  	echo "File ubuntu-12.04.iso doesn't exists"
        	fi
	}
	elif [ $CODENAME = natty ]; then
	{

		/etc/init.d/pgxl-ctrl stop
	 	if [ -f ubuntu-11.10-i386.iso ]; then
                	mkdir /tmp/mou
                	mount -o loop ubuntu-11.10-i386.iso /tmp/mou/
                	/tmp/mou/cdromupgrade --without-network frontend=DistUpgradeViewText
        	else
                	echo "File ubuntu-11.10.iso doesn't exists"
        	fi
	}
	elif [ $CODENAME = maverick ]; then
	{

		/etc/init.d/pgxl-ctrl stop
		if [ -f ubuntu-11.04-i386.iso ]; then
                	mkdir /tmp/mou
                	mount -o loop ubuntu-11.04-i386.iso /tmp/mou/
                	/tmp/mou/cdromupgrade --without-network frontend=DistUpgradeViewText
        	else
                	echo "File ubuntu-11.04.iso doesn't exists"
        	fi
	}
	elif [ $CODENAME = precise ]; then
	

		/etc/init.d/pgxl-ctrl stop
		echo -e '\t\t' "Cheers! You're already in 12.04 LTS";
		Os_ver=$(cat /etc/issue.net)
                echo -e '\t\t'"You have succesfully Upgrade the OS to:$Os_ver" -e '\n'
		echo -e '\n'
		

		#Check the kernel version and updates the system
		rm -r /tmp/kv
		uname -r | eval sed "s/[^0-9]//g" > /tmp/kv
		k_version=$(grep -o '^.\{3\}' /tmp/kv)
		if [ $k_version -lt "350" ]; then
			cp sources.list /etc/apt/
               		apt-get -y update
			dpkg --configure -a
			apt-get -y install -f
			apt-get -y upgrade
			apt-get -y install linux-image-generic-lts-quantal
		#Reboot the system
			init 6
		else
		#Disable apparomor service in the PSG
			echo "Going to upgrade PSG firmware........"
			/etc/init.d/apparmor teardown
                	/etc/init.d/apparmor stop
                	update-rc.d -f apparmor remove
                	apt-get -y remove apparmor
		#Remove softlink sh which points to /bin/dash
		#And create a new softlink sh which point to /bin/bash
			rm /bin/sh
			cd /bin/
			ln -s /bin/bash sh
		#Upgrade the PSG Firmware
			echo -e '\t\t' "Need to Upgrade PSG Image";
                	echo -e '\t\t' "Do you want to continue?...y/n"  
                	read ans
                	case $ans in
                	"y") echo "Enter the Image Path"
			     read url
			     sys_upgrade -R $url;;
                        "n") exit ;;
                	esac
                	if [ $? -eq 0 ]; then
                		echo "You have successfully upgrade the PSG Firmware"
                        	vers=$(cat /etc/phc_version)
                        	echo "Currrent version is: $vers" 
                	fi

		fi	
	else
		echo "Sorry! This version of ubuntu is unknown for me\n";
	fi


}
main



				
			
				




