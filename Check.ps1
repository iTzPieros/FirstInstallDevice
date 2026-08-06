$regPath = "HKLM:\SYSTEM\CurrentControlSet\Enum"
$script:results = @()

function Get-FirstInstallDate {
    param([string]$Path)

    try {
        $item = Get-Item -Path $Path -ErrorAction Stop
        $subkeys = $item.GetSubKeyNames()

        foreach ($sub in $subkeys) {
            $fullPath = "$Path\$sub"
            try {
                $props = Get-ItemProperty -Path $fullPath -ErrorAction Stop

                if ($props.PSObject.Properties["Driver"] -or $props.PSObject.Properties["ConfigFlags"]) {

                    $deviceDesc   = $props.DeviceDesc -replace ".*?;", ""
                    $friendlyName = $props.FriendlyName
                    $hwid         = if ($props.HardwareID) { ($props.HardwareID | Select-Object -First 1) } else { "N/A" }
                    $mfg          = $props.Mfg -replace ".*?;", ""

                    $firstInstall = $null
                    $propsKeyPath = "$fullPath\Properties\{83da6326-97a6-4088-9453-a1923f573b29}"
                    $dateKeys     = @("0065", "0064", "0066")

                    foreach ($dateKey in $dateKeys) {
                        $fullDatePath = "$propsKeyPath\$dateKey"
                        try {
                            $regKey = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey(
                                $fullDatePath.Replace("HKLM:\", "")
                            )
                            if ($regKey) {
                                $data = $regKey.GetValue("(default)")
                                if ($data -and $data.Length -ge 8) {
                                    $ft = [System.BitConverter]::ToInt64($data, 0)
                                    if ($ft -gt 0) {
                                        $firstInstall = [System.DateTime]::FromFileTimeUtc($ft).ToLocalTime()
                                        $regKey.Close()
                                        break
                                    }
                                }
                                $regKey.Close()
                            }
                        } catch {}
                    }

                    $displayName = if ($friendlyName) { $friendlyName } elseif ($deviceDesc) { $deviceDesc } else { "Dispositivo sconosciuto" }

                    $script:results += [PSCustomObject]@{
                        Nome             = $displayName
                        Produttore       = if ($mfg) { $mfg } else { "N/A" }
                        HardwareID       = $hwid
                        PrimaConnessione = if ($firstInstall) { $firstInstall.ToString("dd/MM/yyyy HH:mm:ss") } else { "N/D" }
                    }
                }

            } catch {}

            Get-FirstInstallDate -Path $fullPath
        }
    } catch {}
}

Write-Host "`n[*] Scansione dispositivi in corso..." -ForegroundColor Cyan

Get-FirstInstallDate -Path $regPath

$sorted = $script:results | Sort-Object {
    if ($_.PrimaConnessione -eq "N/D") { [DateTime]::MaxValue }
    else { [DateTime]::ParseExact($_.PrimaConnessione, "dd/MM/yyyy HH:mm:ss", $null) }
}

Write-Host "[+] Trovati $($script:results.Count) dispositivi`n" -ForegroundColor Green

$sorted | Format-Table -AutoSize -Property Nome, Produttore, PrimaConnessione, HardwareID

$csvPath = "$env:USERPROFILE\Desktop\dispositivi_prima_connessione.csv"
$sorted | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
Write-Host "[+] Report esportato in: $csvPath" -ForegroundColor Green
