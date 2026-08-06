$results = [System.Collections.Generic.List[PSCustomObject]]::new()

Write-Host "`n[*] Scansione dispositivi di sistema in corso..." -ForegroundColor Cyan

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[!] ATTENZIONE: non sei amministratore, i risultati saranno tutti N/D" -ForegroundColor Red
}

$devices = Get-PnpDevice -Class System -ErrorAction SilentlyContinue

foreach ($dev in $devices) {
    $installProp = Get-PnpDeviceProperty -InstanceId $dev.InstanceId -KeyName 'DEVPKEY_Device_InstallDate' -ErrorAction SilentlyContinue
    $mfgProp     = Get-PnpDeviceProperty -InstanceId $dev.InstanceId -KeyName 'DEVPKEY_Device_Manufacturer' -ErrorAction SilentlyContinue

    $firstInstall = "N/D"
    if ($installProp -and $installProp.Data -and $installProp.Data -ne [DateTime]::MinValue) {
        $firstInstall = $installProp.Data.ToLocalTime().ToString("dd/MM/yyyy HH:mm:ss")
    }

    $mfg  = if ($mfgProp -and $mfgProp.Data) { $mfgProp.Data } else { "N/D" }
    $hwid = if ($dev.HardwareID) { $dev.HardwareID | Select-Object -First 1 } else { "N/A" }

    $results.Add([PSCustomObject]@{
        Nome             = $dev.FriendlyName
        Produttore       = $mfg
        HardwareID       = $hwid
        PrimaConnessione = $firstInstall
    })
}

$sorted = $results | Sort-Object {
    if ($_.PrimaConnessione -eq "N/D") { [DateTime]::MaxValue }
    else { [DateTime]::ParseExact($_.PrimaConnessione, "dd/MM/yyyy HH:mm:ss", $null) }
}

Write-Host "[+] Trovati $($results.Count) dispositivi di sistema`n" -ForegroundColor Green
$sorted | Format-Table -AutoSize -Property Nome, Produttore, PrimaConnessione, HardwareID

$conValidi = ($sorted | Where-Object { $_.PrimaConnessione -ne "N/D" }).Count
Write-Host "[i] Dispositivi con data valida: $conValidi su $($results.Count)" -ForegroundColor Yellow

$csvPath = "$env:USERPROFILE\Desktop\dispositivi_sistema.csv"
$sorted | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
Write-Host "[+] Report esportato in: $csvPath" -ForegroundColor Green
