#!/bin/bash

# Colours

red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
cyan=$(tput setaf 6)
white=$(tput setaf 7)

# Messages
INFO=$white'['$yellow'*'$white']'
EROR=$white'['$red'-'$white']'
SUCC=$white'['$green'+'$white']'
INPT=$white'['$cyan'>'$white']'

trap 'printf "\n$INFO Caught Ctrl+C. Exiting.\n"; exit 1' SIGINT


echo "*** Please ensure your UPSTREAM(Internet) network interface"
echo "is already connected! *** "

function ap_config {
	read -p "$INPT Select interface [wlan1]: " iface
	if [ -z "$iface" ]
		then
		iface="wlan1"
	fi

	read -p "$INPT Set ESSID [HelloUniverse]: " essid
	if [ -z "$essid" ]
		then
		essid="HelloUniverse"
	fi

	read -p "$INPT Set channel [1]: " channel
	if [ -z "$channel" ]
		then
		channel="1"
	fi
}

function mode_airbase {

	function base_cleanup {
		echo "$INFO Flushing iptables.."
		iptables --flush
		iptables -t nat --flush

		echo "$INFO Disabling ip forwarding.."
		echo 0 > /proc/sys/net/ipv4/ip_forward

		echo "$INFO Stopping Web / DHCP services.."
		systemctl stop dnsmasq
		systemctl stop apache2
		systemctl stop mysql

		echo "$INFO Removing monitor interface.."
		airmon-ng stop $iface\mon

		echo "$INFO Restoring network services.."
		systemctl start network-manager
		systemctl start wpa_supplicant

		echo "$SUCC Done!"
		exit 0
	}


	function base_setup {
		trap 'printf "\n$INFO Caught Ctrl+C. Cleaning up.\n"; base_cleanup' SIGINT
		echo "$INFO Clearing iptables.."
		iptables --flush
		iptables --delete-chain
		iptables -t nat --flush
		iptables -t nat --delete-chain

		echo "$INFO Set iptables rules.."
		iptables -t nat -A POSTROUTING -o $iface -j MASQUERADE
		iptables -A FORWARD -i at0 -j ACCEPT
		iptables -t nat -A PREROUTING -p tcp --dport 80 -j DNAT --to-destination 10.0.0.1:80
		iptables -t nat -A POSTROUTING -j MASQUERADE

		echo "$INFO Enabling ip forwarding.."
		echo 1 > /proc/sys/net/ipv4/ip_forward

		echo "$INFO Stopping network services.."
		systemctl stop network-manager
		systemctl stop wpa_supplicant

		echo "$INFO Starting Web / DHCP services.."
		systemctl start dnsmasq
		systemctl start apache2
		systemctl start mysql

		echo "$INFO Starting monitor interface.."
		airmon-ng start $iface

		echo "$INFO Starting airbase.."
		airbase-ng -e "$essid" -c $channel $iface\mon
	}
	ap_config
	base_setup
}


function mode_hostapd {

	function apd_config {
		echo "$INFO Backing up hostapd.conf to /root/hostapd.conf.backup"
		if [ ! -f /root/hostapd.conf.backup ]
		then
			cp /etc/hostapd/hostapd.conf /root/hostapd.conf.backup
		else
			echo "$INFO hostapd.conf.backup exists!"
			read -p "$INPT Replace backup? [y/N]: " repl
			if [[( -z $repl ) || ( "$repl" = 'n' ) || ( "$repl" = 'N' )]]
			then
				echo #does nothing
			else
				cp "/etc/hostapd/hostapd.conf" "/root/hostapd.conf.backup"
			fi
		fi
	}

	function apd_cleanup {
		echo "$INFO Flushing iptables.."
		iptables --flush
		iptables -t nat --flush

		echo "$INFO Disabling ip forwarding.."
		echo 0 > /proc/sys/net/ipv4/ip_forward

		echo "$INFO Stopping Web / DHCP services.."
		systemctl stop dnsmasq
		systemctl stop apache2
		systemctl stop mysql

#		echo "$INFO Restoring network services.."
#		systemctl start network-manager
#		systemctl start wpa_supplicant

		echo "$SUCC Done!"
		exit 0
	}


	function apd_setup {
		trap 'printf "\n$INFO Caught Ctrl+C. Cleaning up.\n"; apd_cleanup' SIGINT

		echo "$INFO Configuring hostapd.conf.."
		echo interface=$iface > /etc/hostapd/hostapd.conf
		echo ssid=$essid >> /etc/hostapd/hostapd.conf
		echo channel=$channel >> /etc/hostapd/hostapd.conf

		echo "$INFO Clearing iptables.."
		iptables --flush
		iptables --delete-chain
		iptables -t nat --flush
		iptables -t nat --delete-chain

		echo "$INFO Set iptables rules.."
		iptables -t nat -A POSTROUTING -o $iface -j MASQUERADE
		iptables -A FORWARD -i at0 -j ACCEPT
		iptables -t nat -A PREROUTING -p tcp --dport 80 -j DNAT --to-destination 10.0.0.1:80
		iptables -t nat -A POSTROUTING -j MASQUERADE

		echo "$INFO Enabling ip forwarding.."
		echo 1 > /proc/sys/net/ipv4/ip_forward

#		echo "$INFO Stopping network services.."
#		systemctl stop network-manager
#		systemctl stop wpa_supplicant

		echo "$INFO Starting Web / DHCP services.."
		systemctl start dnsmasq
		systemctl start apache2
		systemctl start mysql

		echo "$INFO Starting hostapd.."
		hostapd /etc/hostapd/hostapd.conf
	}
	ap_config
	apd_config
	apd_setup
}

function mode_select {
	read -p "$INPT Select airbase/hostapd mode [A/h]: " sel
	if [[( -z "$sel" ) || ( "$sel" = 'a' ) || ( "$sel" = 'A')]]
		then
		echo "$SUCC Selected airbase mode."
		mode_airbase
	else
		if [[( "$sel" = 'h' ) || ( "$sel" = 'H' )]]
			then
			echo "$SUCC Selected hostapd mode."
			mode_hostapd
		else
			echo $EROR "Invalid input! Use 'a/A/h/H'."
			mode_select
		fi
	fi
}


mode_select
exit 0
