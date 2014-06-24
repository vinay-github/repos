#!/bin/sh

#	Date: 29 Jan 2014
#
#Script to adds ip rules for authentication.
#This script retrieves configuration from $pginit_confdump
#
#-------------------------------------------------------------------
#                               Usage                                           
#-------------------------------------------------------------------
# $ sh authenticate.sh
# 
#
# CHOICE=1 (Authenticate) 
# CHOICE=2 (Unauthenticate)
#------------------------------------------------------------------


#--------------------Configurationi Starts-------------------------------
CHOICE=1
#--------------------Configuration Ends----------------------------------


WAN=`pginit_confdump -active-wan | grep interface_name | awk '{ print $2 }' | tail -1`;
if [ $WAN = "eth0.2" ]; then
	WAN=eth0;
fi

LAN_COUNT=`pginit_confdump | grep dhcp_config_entries: | awk '{ print $2 }'`;
OUT_RATE=`pginit_confdump | grep acl_config.acl_qos.out_min_bw | awk '{ print $2 }'`kbit;
OUT_CEIL=`pginit_confdump | grep acl_config.acl_qos.out_max_bw | awk '{ print $2 }'`kbit;
IN_RATE=`pginit_confdump | grep acl_config.acl_qos.in_min_bw | awk '{ print $2 }'`kbit;
IN_CEIL=`pginit_confdump | grep acl_config.acl_qos.in_max_bw | awk '{ print $2 }'`kbit;

main()
{
	cnt=65
	for i in `seq 1 $LAN_COUNT`
	do
		
		LAN=`pginit_confdump | grep dhcp_config | grep -m $i interface_name | awk '{ print $2 }' | tail -1`
		ALAN=`pginit_confdump | grep dhcp_config | grep -m $i interface_name | awk '{ print $2 }' | tail -1`
		if [ $LAN != "wlan1" -a $LAN != 'wlan2' -a $LAN != 'Wlan1' -a $LAN != 'Wlan2' ]; then
			LAN="eth0";
		fi
		
		START_A=`pginit_confdump | grep ranges | grep -m $i start | awk '{ print $2 }' | awk -F [.] '{ print $1 }' | tail -1`
		START_B=`pginit_confdump | grep ranges | grep -m $i start | awk '{ print $2 }' | awk -F [.] '{ print $2 }' | tail -1`
		START_C=`pginit_confdump | grep ranges | grep -m $i start | awk '{ print $2 }' | awk -F [.] '{ print $3 }' | tail -1`
		START_D=`pginit_confdump | grep ranges | grep -m $i start | awk '{ print $2 }' | awk -F [.] '{ print $4 }' | tail -1`

		END_A=`pginit_confdump | grep ranges | grep -m $i end | awk '{ print $2 }' | awk -F [.] '{ print $1 }' | tail -1`
		END_B=`pginit_confdump | grep ranges | grep -m $i end | awk '{ print $2 }' | awk -F [.] '{ print $2 }' | tail -1`
		END_C=`pginit_confdump | grep ranges | grep -m $i end | awk '{ print $2 }' | awk -F [.] '{ print $3 }' | tail -1`
		END_D=`pginit_confdump | grep ranges | grep -m $i end | awk '{ print $2 }' | awk -F [.] '{ print $4 }' | tail -1`
		config $LAN $START_C $START_D $END_C $END_D $START_A $START_B $END_A $END_B $ALAN
	done


}

config()
{
	LAN=$1
	START_C=$2
	START_D=$3
	END_C=$4
	END_D=$5
	START_A=$6
	START_B=$7
	END_A=$8
	END_B=$9
	ALAN=$10

	if [ $CHOICE -eq 1 ]; then
		m=`expr $END_D - $START_D + 1`;	
		
		/usr/sbin/iptables -t nat -N $START_A.$START_B.$START_C"_CHAIN" > /dev/null 2>&1;
                /usr/sbin/iptables -t filter -N $START_A.$START_B.$START_C"_CHAIN" > /dev/null 2>&1;
                /usr/sbin/iptables -t mangle -N $START_A.$START_B.$START_C"_CHAIN" > /dev/null 2>&1;
                /usr/sbin/iptables -t nat -I SUBNET_CHAIN -s $START_A.$START_B.$START_C.0/24 -j $START_A.$START_B.$START_C"_CHAIN"
                /usr/sbin/iptables -t filter -I SUBNET_CHAIN -s $START_A.$START_B.$START_C.0/24 -j $START_A.$START_B.$START_C"_CHAIN"
                /usr/sbin/iptables -t filter -I SUBNET_CHAIN -d $START_A.$START_B.$START_C.0/24 -j $START_A.$START_B.$START_C"_CHAIN"
                /usr/sbin/iptables -t mangle -I SUBNET_CHAIN -s $START_A.$START_B.$START_C.0/24 -j $START_A.$START_B.$START_C"_CHAIN"
                /usr/sbin/iptables -t mangle -I SUBNET_CHAIN -d $START_A.$START_B.$START_C.0/24 -j $START_A.$START_B.$START_C"_CHAIN"
			
		hc=`printf "%x" $START_C`;
                hb=`printf "%x" $START_B`;
                ha=`printf "%x" $START_A`;
			
		for i in `seq 1 $m`
		do	
			cnt2=`expr $cnt + 1000`;
			hd=`expr $START_D + 1`;
			hd=`printf "%x" $hd`;
				
			/usr/sbin/iptables -t nat -I $START_A.$START_B.$START_C"_CHAIN" -i $ALAN -s $START_A.$START_B.$START_C.$START_D -j POSTAUTH
                        /usr/sbin/iptables -t filter -I $START_A.$START_B.$START_C"_CHAIN" -i $ALAN -s $START_A.$START_B.$START_C.$START_D -j ACCEPT
			/usr/sbin/iptables -t mangle -I $START_A.$START_B.$START_C"_CHAIN" -i $ALAN -s $START_A.$START_B.$START_C.$START_D -j ACCEPT
			/usr/sbin/iptables -t mangle -I $START_A.$START_B.$START_C"_CHAIN" -i $ALAN -s $START_A.$START_B.$START_C.$START_D -j MARK --set-mark $cnt2
			/usr/sbin/iptables -t mangle -I INPUT_CLIENT -i $ALAN ! -p icmp -s $START_A.$START_B.$START_C.$START_D -j ACCEPT
			/usr/sbin/tc filter add dev $WAN parent 1:0 protocol all prio 2 handle $cnt2 fw classid 1:$cnt2
			/usr/sbin/tc filter add dev $LAN parent 1:0 protocol all prio 5 handle $hd:$hc:$hb u32 ht $hd:$hc: match ip dst $START_A.$START_B.$START_C.$START_D classid 1:$cnt
			/usr/sbin/tc class add dev $LAN parent 1:17 classid 1:$cnt htb rate $IN_RATE ceil $IN_CEIL
			/usr/sbin/tc class add dev $WAN parent 1:1017 classid 1:$cnt2 htb rate $OUT_RATE ceil $OUT_CEIL;
			cnt=`expr $cnt + 1`;
			START_D=`expr $START_D + 1`
		done
	elif [ $CHOICE -eq 2 ]; then
                
		m=`expr $END_D - $START_D + 1`
		/usr/sbin/iptables -t nat -D SUBNET_CHAIN -s $START_A.$START_B.$START_C.0/24 -j $START_A.$START_B.$START_C"_CHAIN"   
		/usr/sbin/iptables -t filter -D SUBNET_CHAIN -s $START_A.$START_B.$START_C.0/24 -j $START_A.$START_B.$START_C"_CHAIN"
		/usr/sbin/iptables -t filter -D SUBNET_CHAIN -d $START_A.$START_B.$START_C.0/24 -j $START_A.$START_B.$START_C"_CHAIN"
		/usr/sbin/iptables -t mangle -D SUBNET_CHAIN -s $START_A.$START_B.$START_C.0/24 -j $START_A.$START_B.$START_C"_CHAIN"
		/usr/sbin/iptables -t mangle -D SUBNET_CHAIN -d $START_A.$START_B.$START_C.0/24 -j $START_A.$START_B.$START_C"_CHAIN"
		                                                                
		hc=`printf "%x" $START_C`;
                hb=`printf "%x" $START_B`;
                ha=`printf "%x" $START_A`;

		for i in `seq 1 $m`
                do
                	cnt2=`expr $cnt + 1000`
			hd=`expr $START_D + 1`;
                        hd=`printf "%x" $hd`;

			/usr/sbin/iptables -t nat -D $START_A.$START_B.$START_C"_CHAIN" -i $ALAN -s $START_A.$START_B.$START_C.$START_D -j POSTAUTH
                        /usr/sbin/iptables -t filter -D $START_A.$START_B.$START_C"_CHAIN" -i $ALAN -s $START_A.$START_B.$START_C.$START_D -j ACCEPT 
                        /usr/sbin/iptables -t mangle -D $START_A.$START_B.$START_C"_CHAIN" -i $ALAN -s $START_A.$START_B.$START_C.$START_D -j ACCEPT
                        /usr/sbin/iptables -t mangle -D $START_A.$START_B.$START_C"_CHAIN" -i $ALAN -s $START_A.$START_B.$START_C.$START_D -j MARK --set-mark $cnt2
                        /usr/sbin/iptables -t mangle -D INPUT_CLIENT -i $ALAN ! -p icmp -s $START_A.$START_B.$START_C.$START_D -j ACCEPT
                        /usr/sbin/tc filter del dev $WAN parent 1:0 protocol all prio 2 handle $cnt2 fw classid 1:$cnt2
                        /usr/sbin/tc filter del dev $LAN parent 1:0 protocol all prio 5 handle $hd:$hc:$hb u32 ht $hd:$hc: match ip dst $START_A.$START_B.$START_C.$START_D classid 1:$cnt
                        /usr/sbin/tc class del dev $LAN parent 1:17 classid 1:$cnt htb rate $IN_RATE ceil $IN_CEIL
                        /usr/sbin/tc class del dev $WAN parent 1:1017 classid 1:$cnt2 htb rate $OUT_RATE ceil $OUT_CEIL;	
			cnt=`expr $cnt + 1`;
			START_D=`expr $START_D + 1`;
		done
	else
		echo "Invalid choice"
	fi
}
main $*
