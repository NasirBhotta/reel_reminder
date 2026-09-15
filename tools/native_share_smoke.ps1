param([string]$Serial = 'emulator-5580')
$ErrorActionPreference = 'Stop'
$package = 'com.example.reel_reminder'
$suffix = [guid]::NewGuid().ToString('N')
$coldUrl = "https://youtu.be/native-cold-$suffix"
$warmUrl = "https://www.instagram.com/reel/native-warm-$suffix/"
$plainUrl = "https://reddit.com/r/native-$suffix"
function Invoke-Adb([string[]]$Arguments) {
    $output = & adb -s $Serial @Arguments
    if ($LASTEXITCODE -ne 0) { throw "ADB failed: $Arguments" }
    return $output
}
$targets = Invoke-Adb @('shell', 'cmd', 'package', 'query-activities', '--brief', '-a', 'android.intent.action.SEND', '-t', 'text/plain')
if (($targets -join "`n") -notmatch [regex]::Escape($package)) { throw 'App is not registered as a text share target.' }
Invoke-Adb @('shell', 'am', 'force-stop', $package) | Out-Null
Invoke-Adb @('shell', 'am', 'start', '-W', '-a', 'android.intent.action.SEND', '-t', 'text/plain', '--es', 'android.intent.extra.TEXT', $coldUrl, '-n', "$package/.MainActivity") | Out-Null
$coldPid = Invoke-Adb @('shell', 'pidof', $package)
Invoke-Adb @('shell', 'am', 'start', '-W', '-a', 'android.intent.action.SEND', '-t', 'text/plain', '--es', 'android.intent.extra.TEXT', $warmUrl, '-n', "$package/.MainActivity") | Out-Null
$warmPid = Invoke-Adb @('shell', 'pidof', $package)
if ($coldPid -ne $warmPid) { throw 'Warm intake restarted the process unexpectedly.' }
Invoke-Adb @('shell', "am start -W -a android.intent.action.SEND -t text/plain --es android.intent.extra.TEXT 'Check this $plainUrl' -n $package/.MainActivity") | Out-Null
function Assert-Inbox {
    $deadline = (Get-Date).AddSeconds(15)
    do {
        $xmlText = Invoke-Adb @('shell', 'run-as', $package, 'cat', 'shared_prefs/share_inbox.xml')
        $xml = [xml]($xmlText -join "`n")
        $json = ($xml.map.string | Where-Object { $_.name -eq 'items' }).InnerText
        $items = @($json | ConvertFrom-Json)
        if (($items.text -contains $coldUrl) -and ($items.text -contains $warmUrl) -and ($items.text -contains "Check this $plainUrl")) { return }
        Start-Sleep -Milliseconds 200
    } while ((Get-Date) -lt $deadline)
    throw 'Cold/warm share missing from durable inbox after timeout.'
}
Assert-Inbox
Invoke-Adb @('shell', 'am', 'force-stop', $package) | Out-Null
Invoke-Adb @('shell', 'am', 'start', '-W', '-n', "$package/.MainActivity") | Out-Null
Assert-Inbox
Write-Output 'PASS: Share target registration, cold intake, same-process warm intake, text containing a URL, and inbox persistence after force-stop.'
Write-Output 'This smoke test checks signed-out native intake; it does not prove authenticated Firestore delivery.'
