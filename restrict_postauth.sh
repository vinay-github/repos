#!/bin/sh

# This script do "post authentication restriction" based on the IPs 
# which are assigned to a variable "net_list".



########### Usage ############

# Example 1:	to enable restriction 	
#		$ sh restrict_postauth.sh 0


# Example 2:	to disable restriction
#		$ sh restrict_postauth.sh 1


#net_list="216.239.32.0/19 64.233.160.0/19 66.249.80.0/20 72.14.192.0/18 209.85.128.0/17 66.102.0.0/20 74.125.0.0/16 64.18.0.0/20 207.126.144.0/20 173.194.0.0/16"

main()
{
	net_list="216.239.32.0/19 64.233.160.0/19 66.249.80.0/20 72.14.192.0/18 209.85.128.0/17 66.102.0.0/20 74.125.0.0/16 64.18.0.0/20 207.126.144.0/20 173.194.0.0/16"

	/bin/grep 'PHCXL' /etc/phc_version
	

	if [ $? -eq 0 ]; then
	{
		if [ $1 -eq 0 ];then
                {
                        /sbin/iptables -N POSTAUTH > /dev/null 2>&1
                        /sbin/iptables -I RATE_LIMIT -j POSTAUTH
                        /sbin/iptables -I POSTAUTH -j DROP
                        for net in $net_list
                        do
                                /sbin/iptables -I POSTAUTH -p tcp -d $net -j ACCEPT
                        done 
                }
                elif [ $1 -eq 1 ];then
                {
                        /sbin/iptables -D RATE_LIMIT -j POSTAUTH
                        for net in $net_list
                        do
                                /sbin/iptables -D POSTAUTH -p tcp -d $net -j ACCEPT
                        done
                        /sbin/iptables -D POSTAUTH -j DROP 
                }
                fi
	}
	else
	{
		if [ $1 -eq 0 ];then
		{
			/usr/sbin/iptables -N POSTAUTH > /dev/null 2>&1
			/usr/sbin/iptables -I RATE_LIMIT -j POSTAUTH
			/usr/sbin/iptables -I POSTAUTH -j DROP
			for net in $net_list
			do
				/usr/sbin/iptables -I POSTAUTH -p tcp -d $net -j ACCEPT
			done
			
			/bin/sed -i 's/\-o\ \$\$PRI\-OUT\-IF\-NAME\$\$\ \-s\ \$\$CLIENT\-IP\$\$\ \%\%IPSPOOF\%\%\ \-j\ \ACCEPT/\-o\ \$\$PRI\-OUT\-IF\-NAME\$\$\ \-s\ \$\$CLIENT\-IP\$\$\ \%\%IPSPOOF\%\%\ \-j\ \RATE_LIMIT/g' /etc/templates/auth_iprules.tem
	
		}
	
		elif [ $1 -eq 1 ];then
		{
			/usr/sbin/iptables -D RATE_LIMIT -j POSTAUTH	
		        for net in $net_list
		        do
		                /usr/sbin/iptables -D POSTAUTH -p tcp -d $net -j ACCEPT
		        done	
			/usr/sbin/iptables -D POSTAUTH -j DROP
	
			/bin/sed -i 's/\-o\ \$\$PRI\-OUT\-IF\-NAME\$\$\ \-s\ \$\$CLIENT\-IP\$\$\ \%\%IPSPOOF\%\%\ \-j\ \RATE_LIMIT/\-o\ \$\$PRI\-OUT\-IF\-NAME\$\$\ \-s\ \$\$CLIENT\-IP\$\$\ \%\%IPSPOOF\%\%\ \-j\ \ACCEPT/g' /etc/templates/auth_iprules.tem

		}
		fi		
	}
	fi
}

main $*
