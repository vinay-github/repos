#!/bin/bash

#This script upgrades the firmware of wavespot based on wan type(static or dhcp)
#URLs should be accurate at config section

#---------------------Config Section Starts--------------------------------#

FIRMWARE="http://app.wavespot.net/WAVESPOT-6.0.2.75-squashfs-sysupgrade.bin"
SYSUP="http://oss.wavespot.net/oss_cs_ws/sysupgrade"
SYS_UP="http://oss.wavespot.net/oss_cs_ws/sys_upgrade"

#---------------------Config Section Ends----------------------------------#


main()
{
	for macup in $macs
	do
		wan_mac_addr=`/bin/cat /usr/scripts/interface.conf  | grep NASID= | /usr/bin/awk '{ print $2 }' | cut -d'=' -f2`;
		if [ "$wan_mac_addr" = $macup ]; then
        		/bin/grep 73 /etc/phc_version
        		if [ $? -ne 0 ];then
        		        if [ -f "/tmp/upgradeinprogress" ]; then
        		                exit 0;
        		        fi
        		        echo "touch" > /tmp/upgradeinprogress

				#downloading firmware
        		        wget $FIRMWARE -O /tmp/firmware
        		        if [ $? -ne 0 ];then
        		                exit 0;
        		        fi
				
				#downloading sysupgrade file
        		        wget $SYSUP -O /tmp/sysupgrade
        		        if [ $? -ne 0 ];then
                		        exit 0;
                		fi
				#downloading sys_upgrade file
				wget $SYS_UP -O /tmp/sys_upgrade
                                if [ $? -ne 0 ];then
                                        exit 0;
                                fi
				
				#Upgrading based on wan configuration
				/sbin/uci get network.wan.proto | grep -i dhcp
				if [ $? -ne 0 ];then
                			chmod 755 /tmp/sysupgrade
                			cp -f /tmp/sysupgrade /sbin/sysupgrade
                			/tmp/sysupgrade -n /tmp/firmware &	
                			exit 0;
				else
					chmod 755 /tmp/sys_upgrade
                                        cp -f /tmp/sys_upgrade /sbin/sys_upgrade
                                        /tmp/sys_upgrade -n /tmp/firmware & 
                                        exit 0;
				fi
        		fi
		fi
	done
}
main $* 
