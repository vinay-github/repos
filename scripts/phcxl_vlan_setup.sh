#!/bin/bash

# This script creates vlans using config file.
# This script reads data from /etc/phcconfig/vlan_manual.conf with space separated 
# list of parameters, each line representing confgiration for a new vlan.
# This script can be used for PSG version 6.0.2.75 and 6.0.2.80 as of now (Oct 2013).


# The format for the config file is as follows
# VlanTag ip_address netmask nat_enable 802.1x_enable dhcp_start_ip dhcp_end_ip vlanDescription city_ty_hs picd pid sourceSystem
# EX:   100 192.168.12.1 255.255.255.0 Y N 192.168.12.2 192.168.12.254 vlan_for_block1 campus 63 BX Pronto
# EX:   101 192.168.23.1 255.255.255.0 N Y 192.168.23.2 192.168.23.254 vlan_for_testing cafe 57 AB Pronto

# For nat_enable, value for the parameter is either "Y" to enable or "N" to disable
# For 802.1x_enable, value for the parameter is either "Y" to enable or "N" to disable
# For vlanDescription, value for the parameter should be alphanumeric without space
# For city_ty_hs, value for the parameter should be string without space
# For picd, value for the parameter should be numeric without space
# For pid,value for the parameter should be Alphanumeric without space
# For sourceSystem,value for the parameter should be String without space

# Usage
# sh phcxl_vlan_setup.sh start  To add vlan 
# sh phcxl_vlan_setup.sh stop   To delete vlan


#------------------ Config Section Starts -----------------#

# Path of the jsp file(OSS), where the data to be pushed from PSG
URL="http://192.168.1.127:7777/hns/SetDeviceData.jsp";

# vlan config file's path
CONF="/etc/phcconfig/vlan_manual.conf";

#------------------ Config Section Ends --------------------#






# -------------------- Script starts ------------------------#

# To identify, PSG or PSC
        /bin/grep 'PHCXL' /etc/phc_version > /dev/null 2>&1;
        if [ $? -eq 0 ]; then
                TYPE="PSG";
        else
                TYPE="PSC";
        fi


# To find the nasId
        nasId=`ifconfig eth0 | grep HWaddr | /usr/bin/awk '{ print $5 }'`;


stop() {
	cat $CONF | grep -v '^#' | grep -v "^$" | while read line; do 
		id=`echo $line | /usr/bin/awk '{ print $1 }'`;
		ip=`echo "$line" | /usr/bin/awk '{ print $2 }'`;
		nm=`echo "$line" | /usr/bin/awk '{ print $3 }'`;
		nat=`echo "$line" | /usr/bin/awk '{ print $4 }'`;
		x802=`echo "$line" | /usr/bin/awk '{ print $5 }'`;
		start_ip=`echo "$line" | /usr/bin/awk '{ print $6 }'`;
		end_ip=`echo "$line" | /usr/bin/awk '{ print $7 }'`;

		/sbin/vconfig rem eth1.$id > /dev/null 2>&1;
		/bin/sed -e /eth1.$id\ /,+10d /etc/dhcp/dhcpd.conf >> /etc/dhcp/dhcpd_back.conf;
		/bin/rm -rf /etc/dhcp/dhcpd.conf;
		/bin/mv /etc/dhcp/dhcpd_back.conf /etc/dhcp/dhcpd.conf;

		delete_iptable_rules ${id} ${ip} ${nm} ${nat} ${x802};
	
		#Pushing data from PSG to OSS
		data="action=DEACTIVATE&nasId=$nasId&vlanTag=$id"
		curl -d $data $URL > /dev/null 2>&1;

	done;
}

start() {

	cat $CONF | grep -v '^#' | grep -v "^$" | while read line ; \
	do
		id=`echo "$line" | /usr/bin/awk '{ print $1 }'`;
		ip=`echo "$line" | /usr/bin/awk '{ print $2 }'`;
		nm=`echo "$line" | /usr/bin/awk '{ print $3 }'`;
		nat=`echo "$line" | /usr/bin/awk '{ print $4 }'`;
		x802=`echo "$line" | /usr/bin/awk '{ print $5 }'`;
		start_ip=`echo "$line" | /usr/bin/awk '{ print $6 }'`;
		end_ip=`echo "$line" | /usr/bin/awk '{ print $7 }'`;
		vlanDescription=`echo "$line" | /usr/bin/awk '{ print $8 }'`;

		city_ty_hs=`echo "$line" | /usr/bin/awk '{ print $9 }'`;
		picd=`echo "$line" | /usr/bin/awk '{ print $10 }'`;
		pid=`echo "$line" | /usr/bin/awk '{ print $11 }'`;
		sourceSystem=`echo "$line" | /usr/bin/awk '{ print $12 }'`;
		
		extra=`echo "$line" | /usr/bin/awk '{ print $13 }'`;

		if [ -z $sourceSystem ]; then
			echo "-------------------------------------------------"
			echo "Bad(Missing) parameters in /etc/phcconfig/vlan_manual.conf"
			echo "Please have a look into the script for a example"
			echo "-------------------------------------------------"
			exit 0;
		fi 
	
		if [ ! -z $extra ]; then
			echo "-------------------------------------------------"
			echo "Bad(Extra) parameters in /etc/phcconfig/vlan_manual.conf"
			echo "Please have a look into the script for a example"
			echo "-------------------------------------------------"
                        exit 0;
                fi      
		
		/sbin/vconfig add eth1 "$id" | grep Added > /dev/null 2>&1;
		if [ $? -ne 0 ]; then
			continue;
		fi
	
		/sbin/ifconfig eth1."$id" "$ip" netmask "$nm" broadcast "$ip/$nm" up > /dev/null 2>&1

		add_iptable_rules ${id} ${ip} ${nm} ${nat} ${x802};
	
		snet=`/bin/netstat -rn | /bin/grep -v UG | /bin/grep eth1."$id" | /usr/bin/awk '{print $1}'`;
	
		br=`/sbin/ifconfig eth1."$id" | /bin/grep Bcast | /usr/bin/awk '{print $3}' |  /usr/bin/cut -d':' -f2`;
	
		echo -e "shared-network net_eth1.$id {" >> /etc/dhcp/dhcpd.conf;
		echo -e "\tsubnet $snet  netmask $nm {" >> /etc/dhcp/dhcpd.conf;
		echo -e "\t\trange $start_ip $end_ip;" >> /etc/dhcp/dhcpd.conf;
		echo -e "\t\tmax-lease-time 86400;" >> /etc/dhcp/dhcpd.conf;
		echo -e "\t\tdefault-lease-time 86400;" >> /etc/dhcp/dhcpd.conf;
		echo -e "\t\toption routers $ip;" >> /etc/dhcp/dhcpd.conf;
		echo -e "\t\toption domain-name-servers $ip;" >> /etc/dhcp/dhcpd.conf;
		echo -e "\t\toption subnet-mask $nm;" >> /etc/dhcp/dhcpd.conf;
		echo -e "\t\toption broadcast-address $br;" >> /etc/dhcp/dhcpd.conf;
		echo -e "\t}" >> /etc/dhcp/dhcpd.conf; 
		echo -e "}" >> /etc/dhcp/dhcpd.conf;
	
		
# Pushing data from PSG to OSS
		data="action=ADD&type=$TYPE&nasId=$nasId&vlanTag=$id&vlanDescription=$vlanDescription&vlanInterfaceIP=$ip&vlanSubnet=$nm&vlanDHCPStartIP=$start_ip&vlanDHCPEndIP=$end_ip&vlanNATEnable=$nat&vlan8021x_Enable=$x802&city_ty_hs=$city_ty_hs&picd=$picd&pid=$pid&sourceSystem=$sourceSystem"

		curl -d $data $URL > /dev/null 2>&1;

	done
}


delete_iptable_rules() {
	
	id=$1;
	ip=$2;
	nm=$3;
	nat=$4;
	x802=$5;
	
	proxy=`/bin/pginit_confdump | /bin/grep http_proxy_enabled | /usr/bin/awk '{ print $2 }'`;
	
	if [ $nat != '1' ]; then
		/sbin/iptables -t nat -D POSTROUTING -s $ip/$nm -j ACCEPT  > /dev/null 2>&1;
	fi

	if [ ${x802} == '1' ]; then
		/sbin/iptables -t nat -D CLIENT -i eth1."$id" -j POSTAUTH  > /dev/null 2>&1;
		/sbin/iptables -t filter -D CLIENT -i eth1."$id" -j ACCEPT > /dev/null 2>&1;
	else
		/sbin/iptables -t nat -D PREAUTH -p tcp -d $ip -m multiport --dport 443,80 -j ACCEPT  > /dev/null 2>&1;
		
		if [ $proxy == 'TRUE' ]; then
			/sbin/iptables -t nat -D REMOTE_PROXY -p tcp -d $ip  --dport 80 -j ACCEPT  > /dev/null 2>&1;
		fi
		
		/sbin/iptables -t nat -D PREAUTH -p tcp -d $ip -j ACCEPT  > /dev/null 2>&1;
	fi	
}

add_iptable_rules() {
	
	id=$1;
	ip=$2;
	nm=$3;
	nat=$4;
	x802=$5;
	
	proxy=`/bin/pginit_confdump | /bin/grep http_proxy_enabled | /usr/bin/awk '{ print $2 }'`;
	
	if [ $nat != '1' ]; then
		/sbin/iptables -t nat -I POSTROUTING -s $ip/$nm -j ACCEPT  > /dev/null 2>&1;
	fi

	if [ ${x802} == '1' ]; then
		/sbin/iptables -t nat -I CLIENT -i eth1."$id" -j POSTAUTH  > /dev/null 2>&1;
		/sbin/iptables -t filter -I CLIENT -i eth1."$id" -j ACCEPT > /dev/null 2>&1;
	else
		/sbin/iptables -t nat -A PREAUTH -p tcp -d $ip -m multiport --dport 443,80 -j ACCEPT  > /dev/null 2>&1;
		
		if [ $proxy == 'TRUE' ]; then
			/sbin/iptables -t nat -A REMOTE_PROXY -p tcp -d $ip  --dport 80 -j ACCEPT  > /dev/null 2>&1;
		fi
		
		/sbin/iptables -t nat -A PREAUTH -p tcp -d $ip -j ACCEPT  > /dev/null 2>&1;
	fi	
}


function main () {
	
	if [ "$#" -ne 1 ]; then
		echo -e "\tusage sh /etc/phcconfig/phcxl_vlan_setup.sh start | stop";
		exit 1;
	fi

	if [ ! -f "${CONF}" ]; then
		echo "Configuration File not found";
		exit 1;
	fi

	case $1 in
	start) 
		start
		killall ump dhcpd  > /dev/null 2>&1;
		;;
	stop) 
		stop
		killall ump dhcpd  > /dev/null 2>&1;
		;;
	*) echo "usage sh /etc/phcconfig/phcxl_vlan_setup.sh start | stop";
		;;
	esac

	#restarting ngrep
        killall ngrep  > /dev/null 2>&1;
        /bin/ngrep -c  > /dev/null 2>&1;


	exit 0;
}

main $*;
