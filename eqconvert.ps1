Add-Type -AssemblyName System.Windows.Forms

# Prompt user to select a .txt file
$OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
$OpenFileDialog.Filter = "Text files (*.txt)|*.txt"
$OpenFileDialog.Title = "Select EQ Settings File"
if ($OpenFileDialog.ShowDialog() -ne "OK") { exit }

$txtPath = $OpenFileDialog.FileName
$filename = [System.IO.Path]::GetFileNameWithoutExtension($txtPath)
$lines = Get-Content $txtPath

# Prepare band data
$bands = @()
foreach ($i in 1..8) {
    $bands += @{
        Bypass = 1.0
        Frequency = 0.0
        Gain = 0.0
        Q = 1.0
        Type = 2.0
        Visible = 0.0
    }
}

foreach ($line in $lines) {
    if ($line -match "^Filter (\d+): (ON|OFF) (LSC|PK|HSC) Fc ([\d\.]+) Hz Gain ([\-\d\.]+) dB Q ([\d\.]+)") {
        $idx = [int]$matches[1] - 1
        $on = $matches[2] -eq "ON"
        $type = switch ($matches[3]) {
            "LSC" { 1.0 }
            "PK"  { 2.0 }
            "HSC" { 3.0 }
        }
        $freq = [double]$matches[4]
        $gain = [double]$matches[5]
        $q = [double]$matches[6]
        $bands[$idx].Bypass = if ($on) { 0.0 } else { 1.0 }
        $bands[$idx].Frequency = $freq
        $bands[$idx].Gain = $gain
        $bands[$idx].Q = $q
        $bands[$idx].Type = $type
        $bands[$idx].Visible = 1.0
    }
}

# Output XML
$xml = @()
$xml += '<?xml version="1.0" encoding="UTF-8"?>'
$xml += "<Preset>"
$xml += "  <Info Name=""$filename"" Position=""1""/>"
$xml += "  <Parameters>"

for ($i = 0; $i -lt 8; $i++) {
    $b = $bands[$i]
    $bandNum = $i + 1
    $xml += "    <PARAM id=""Band $bandNum Filter Bypass"" value=""$($b.Bypass)""/>"
    $xml += "    <PARAM id=""Band $bandNum Filter Frequency"" value=""$($b.Frequency)""/>"
    # Gain conversion: value = 10^(dB/20)
    $gainValue = [math]::Pow(10, $b.Gain / 20)
    $xml += "    <PARAM id=""Band $bandNum Filter Gain"" value=""$gainValue""/>"
    $xml += "    <PARAM id=""Band $bandNum Filter Quality"" value=""$($b.Q)""/>"
    $xml += "    <PARAM id=""Band $bandNum Filter Type"" value=""$($b.Type)""/>"
    $xml += "    <PARAM id=""Band $bandNum Filter Visible"" value=""$($b.Visible)""/>"
}

$xml += "  </Parameters>"
$xml += "</Preset>"

# Save XML
$xmlPath = [System.IO.Path]::ChangeExtension($txtPath, ".xml")
$xml | Set-Content -Encoding UTF8 $xmlPath

Write-Host "XML file created: $xmlPath"
