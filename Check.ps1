$SYSTEM_CLASS_GUID = "{4d36e97d-e325-11ce-bfc1-08002be10318}"
$results = [System.Collections.Generic.List[PSCustomObject]]::new()

Write-Host "`n[*] Scansione dispositivi di sistema in corso..." -ForegroundColor Cyan

$allKeys = Get-ChildItem -Path "HKLM:\SYSTEM\CurrentControlSet\Enum" -Recurse -ErrorAction SilentlyContinue

foreach ($key in $allKeys) {
    try {
        $props = Get-ItemProperty -Path $key.PSPath -ErrorAction Stop

        $isDevice = $props.PSObject.Properties["Driver"] -or $props.PSObject.Properties["ConfigFlags"]
        $isSystem = $props.ClassGuid -eq $SYSTEM_CLASS_GUID

        if (-not $isDevice -or -not $isSystem) { continue }

        $deviceDesc   = if ($props.DeviceDesc)   { $props.DeviceDesc   -replace ".*?;", "" } else { "" }
        $friendlyName = if ($props.FriendlyName)  { $props.FriendlyName }                   else { "" }
        $hwid         = if ($props.HardwareID)    { $props.HardwareID | Select-Object -First 1 } else { "N/A" }
        $mfg          = if ($props.Mfg)           { $props.Mfg -replace ".*?;", "" }         else { "N/A" }
        $displayName  = if ($friendlyName)         { $friendlyName }                          elseif ($deviceDesc) { $deviceDesc } else { "Sconosciuto" }

        $firstInstall = $null
        $basePath = $key.PSPath.Replace("Microsoft.PowerShell.Core\Registry::", "")
        $dateKeys = @("0065", "0064", "0066")

        foreach ($dateKey in $dateKeys) {
            try {
                $subPath = "$basePath\Properties\{83da6326-97a6-4088-9453-a1923f573b29}\$dateKey"
                $regKey  = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey(
                    $subPath.Replace("HKEY_LOCAL_MACHINE\", "")
                )
                if ($regKey) {
                    $data = $regKey.GetValue("")
                    $regKey.Close()
                    if ($data -and $data.Length -ge 8) {
                        $ft = [System.BitConverter]::ToInt64($data, 0)
                        if ($ft -gt 0) {
                            $firstInstall = [System.DateTime]::FromFileTimeUtc($ft).ToLocalTime()
                            break
                        }
                    }
                }
            } catch {}
        }

        $results.Add([PSCustomObject]@{
            Nome             = $displayName
            Produttore       = $mfg
            HardwareID       = $hwid
            PrimaConnessione = if ($firstInstall) { $firstInstall.ToString("dd/MM/yyyy HH:mm:ss") } else { "N/D" }
        })

    } catch {}
}

$sorted = $results | Sort-Object {
    if ($_.PrimaConnessione -eq "N/D") { [DateTime]::MaxValue }
    else { [DateTime]::ParseExact($_.PrimaConnessione, "dd/MM/yyyy HH:mm:ss", $null) }
}

Write-Host "[+] Trovati $($results.Count) dispositivi di sistema`n" -ForegroundColor Green
$sorted | Format-Table -AutoSize -Property Nome, Produttore, PrimaConnessione, HardwareID

$csvPath = "$env:USERPROFILE\Desktop\dispositivi_sistema.csv"
$sorted | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
Write-Host "[+] Report esportato in: $csvPath" -ForegroundColor Green
