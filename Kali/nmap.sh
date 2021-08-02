#!/bin/bash

## Output file names
active=activehosts
quick=quick
alltcpport=alltcpport
udpport=udpport
allscripts=allscripts
nmapvuln=nmapvuln
vulscan=vulscan



function checkDependencies {
## Check Dependencies
	echo Checking for latest nmap version..
	apt-get update
	apt-get install nmap

	echo Checking if Vulscan has been installed.
	if [ -d "/usr/share/nmap/scripts/vulscan" ]
		then
			echo Vulscan exists!
		else
			read -p "Download vulscan? [Y/n]: " dl_vul
			if [ -z dl_vul ]
				then
					echo Cloning vulscan repo..
					git clone https://github.com/scipag/vulscan /root/scipag_vulscan
					ln -s `pwd`/scipag_vulscan /usr/share/nmap/scripts/vulscan
				else
					echo Vulscan NOT available.
			fi
	fi
	clear
}



function pingScan {
## Get a list of active hosts with a ping sweep and export to a text file.
	read -p "Set target address [xxx.xxx.xxx.xxx]: " targ
	read -p "Set netmask [24]: " netmask
	if [ -z $netmask ]
		then
			netmask='24'
	fi

	read -p "Any excluded IP addresses? [y/N]: " excludech

	if [ -z $excludech ] || [ $excludech = 'n' ]
		then
			nmap -sn $targ/$netmask | grep report | cut -d ' ' -f5 > "$activehosts".txt
	else
		if [ $excludech = 'y' ]
			then
				read -p "Enter excluded IP addressess (Separated by commas): " excludeip
				nmap -sn $targ/$netmask --exclude $excludeip | grep report | cut -d ' ' -f5 > "$activehosts".txt
		fi
	fi
}



function quickScan {
	for i in $(cat $activeOut.txt)
		do
			mkdir $i
			nmap -vv $i -oN ""$i"/"$i"_"$quick".txt"
	done
}



function allPortScan {
	for i in $(cat $activeOut.txt)
		do
			nmap --reason -T4 -p- -vv $i -oN ""$i"/"$i"_"$alltcpport".txt"
	done
}



function udpPortScan {
	for i in $(cat $activeOut.txt)
		do
			nmap --reason -T4 -sU -p- -vv $i -oN ""$i"/"$i"_"$udpport".txt"
	done
}



function allScriptScan {
	for i in $(cat $activeOut.txt)
		do
			nmap --reason -T4 -A -vv $i -oN ""$i"/"$i"_"$allscripts".txt"
	done
}



function nmapVulnScan {
## Standard vuln script scan
	for i in $(cat $activeOut.txt)
		do
			nmap -Pn --script vuln -vv $i -oN ""$i"/"$i"_"$nmapvuln".txt"
	done
}



function vulScan {
## Vulscan script scan
	for i in $(cat $activeOut.txt)
		do
			nmap -sV -Pn --script vulscan --script-args vulscandb=exploitdb.csv -vv $i -oN ""$i"/"$i"_"$vulscan".txt"
	done
}



function main {
# menu
	if [ -f "$(pwd)/$active" ]
		then
			echo === Detected Hosts ===
			cat $active
			echo
			echo
		else
			echo $active.txt not found. Initiating a Ping Scan.
			pingScan
	fi


	echo Nmap scan script for quick use
	echo === Select a scan option ===
	echo 0. Ping Scan
	echo 1. Standard Quick scan - top 1000 ports
	echo 2. All port scan
	echo 3. UDP port scan
	echo 4. All scripts scan - top 1000 ports
	echo 5. Nmap Vuln script scan
	echo 6. Scipag Vulscan script

read -p "Scan Type: " mainch

	if [ "$mainch" = '0' ]
		then
			pingScan
			mainch = ' '
			main
	fi
	if [ "$mainch" = '1' ]
		then
			quickScan
			mainch= ' '
			main
	fi
	if [ "$mainch" = '2' ]
		then
			allPortScan
			mainch= ' '
			main
	fi
	if [ "$mainch" = '3' ]
		then
			udpScan
			mainch= ' '
			main
	fi
	if [ "$mainch" = '4' ]
		then
			allScriptScan
			mainch= ' '
			main
	fi
	if [ "$mainch" = '5' ]
		then
			nmapVulnScan
			mainch= ' '
			main
	fi
	if [ "$mainch" = '6' ]
		then
			vulScan
			mainch= ' '
			main
	fi
}



function init {
	checkDependencies
	main
}

init
