# Function to write error messages and exit
function Write-ErrorAndExit {
    param(
        [string]$message,
        [int]$exitCode = 1
    )
    Write-Error $message
    exit $exitCode
}

# Step 1: Determine if the device is a laptop
try {
    $chassis = Get-WmiObject Win32_SystemEnclosure -ErrorAction Stop
    $chassisTypes = $chassis.ChassisTypes
} catch {
    Write-ErrorAndExit "Error retrieving chassis type: $_"
}

$laptopTypes = @(8,9,10,11,12,14,30,31)
$isLaptop = $false

foreach ($type in $chassisTypes) {
    if ($laptopTypes -contains $type) {
        $isLaptop = $true
        break
    }
}

if (-not $isLaptop) {
    # Device is not a laptop, exit the script
    exit 0
}

# Step 2: Check if connected via Wi-Fi
try {
    $wifiAdapters = Get-NetAdapter -Physical |
        Where-Object {$_.InterfaceDescription -match 'Wi-Fi'} -ErrorAction Stop
} catch {
    Write-ErrorAndExit "Error retrieving network adapters: $_"
}

if (-not $wifiAdapters) {
    # No wireless adapters found
    exit 0
}

# Check if any wireless adapter is connected
$connectedWifiAdapters = $wifiAdapters | Where-Object {$_.Status -eq 'Up'}

if (-not $connectedWifiAdapters) {
    # No connected wireless adapters
    exit 0
}

# Step 3: Get BSSID and SSID, default SSID to 'NoSSID' if blank
try {
    $netshOutput = netsh wlan show interfaces
    $bssidLine = $netshOutput | Select-String -Pattern '^\s*BSSID\s*:\s*(.+)$'
    $ssidLine = $netshOutput | Select-String -Pattern '^\s*SSID\s*:\s*(.+)$'
    
    if ($bssidLine) {
        $bssid = $bssidLine.Matches[0].Groups[1].Value.Trim()
    } else {
        Write-ErrorAndExit "BSSID not found in netsh output."
    }

    if ($ssidLine) {
        $ssid = $ssidLine.Matches[0].Groups[1].Value.Trim()
        if (-not $ssid) {
            $ssid = "NoSSID"
        }
    } else {
        $ssid = "NoSSID"
    }
} catch {
    Write-ErrorAndExit "Error retrieving BSSID and SSID: $_"
}

# Step 4: Write BSSID, SSID, and datetime to the registry only if BSSID has changed
$registryPath = 'HKLM:\SOFTWARE\YourCompany\WiFiInfo'

try {
    if (-not (Test-Path $registryPath)) {
        New-Item -Path $registryPath -Force | Out-Null
    }

    # Check if the BSSID has changed
    $storedBSSID = (Get-ItemProperty -Path $registryPath -Name 'BSSID' -ErrorAction SilentlyContinue).BSSID

    if ($bssid -ne $storedBSSID) {
        # BSSID has changed, update the registry
        Set-ItemProperty -Path $registryPath -Name 'BSSID' -Value $bssid -Force
        Set-ItemProperty -Path $registryPath -Name 'SSID' -Value $ssid -Force
        $currentTime = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Set-ItemProperty -Path $registryPath -Name 'LastUpdated' -Value $currentTime -Force
    } else {
        # BSSID hasn't changed, exit without updating
        exit 0
    }
} catch {
    Write-ErrorAndExit "Error writing to registry: $_"
}

# The script has completed successfully
exit 0
