param([string]$Name = 'screen')
$ErrorActionPreference = 'Stop'
$taskAdb = Join-Path $env:LOCALAPPDATA 'Android/sdk/platform-tools/adb.exe'
$taskRoot = Split-Path $PSScriptRoot -Parent
$taskOutput = Join-Path $taskRoot 'output/emulator-ux'
New-Item -ItemType Directory -Force $taskOutput | Out-Null
$taskName = $Name -replace '[^a-zA-Z0-9_-]', '_'
$taskDump = & $taskAdb shell uiautomator dump /sdcard/healthak-ux.xml
if ($LASTEXITCODE -ne 0 -or "$taskDump" -notmatch 'dumped') {
  throw 'Android UI dump failed; do not use a previous capture for coordinates'
}
$taskXmlPath = Join-Path $taskOutput "$taskName.xml"
& $taskAdb pull /sdcard/healthak-ux.xml $taskXmlPath
& $taskAdb shell screencap -p /sdcard/healthak-ux.png
& $taskAdb pull /sdcard/healthak-ux.png (Join-Path $taskOutput "$taskName.png")
[xml]$taskXml = Get-Content -LiteralPath $taskXmlPath -Raw -Encoding utf8
$taskXml.SelectNodes('//node') | Where-Object {
  $_.text -or $_.'content-desc' -or $_.clickable -eq 'true'
} | ForEach-Object {
  '{0} {1} {2} enabled={3} checked={4}' -f $_.bounds, $_.text, $_.'content-desc', $_.enabled, $_.checked
}
