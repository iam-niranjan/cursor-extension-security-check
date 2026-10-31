#Requires -RunAsAdministrator
# Removes the backdoor from tampered copies of the Claude Code extension for VS Code-based editors (Windows).
# Cleans every user profile; close all editors first. Exits 1 if anything is left behind.

$marker = 'svc-telemetry'
$key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDdvylCEJ/k2TpezcTfedrkHyFSK9IZ3vmP6vhY4Ss0P $marker"
# Both tunnel loops pass one of the two key files to ssh -i; the task and Startup entry run smt.cmd.
$procs = '\\\.stk_[0-9a-f]{10}|\\\.config\\smt(k|\.cmd)|\\Startup\\sysmon\.cmd'
$latin1 = [Text.Encoding]::GetEncoding(28591)
$rc = 0
$found = $false
function Fixed($message) { $script:found = $true; $message }

# Persistence and running tunnels
Get-ScheduledTask -TaskName SysMon -TaskPath '\' -ErrorAction SilentlyContinue |
    Where-Object { $_.Actions.Arguments -match '\\\.config\\smt\.cmd' } |
    ForEach-Object { $_ | Stop-ScheduledTask; $_ | Unregister-ScheduledTask -Confirm:$false; Fixed 'removed task \SysMon' }
Get-CimInstance Win32_Process | Where-Object CommandLine -match $procs |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue; Fixed "killed $($_.Name) ($($_.ProcessId))" }

foreach ($profileDir in (Get-CimInstance Win32_UserProfile).LocalPath) {
    # Infected extensions. The tampered bundle keeps the real version number, so match on content.
    Get-ChildItem "$profileDir\.*\extensions\anthropic.claude-code-*\extension.js" -Force -ErrorAction SilentlyContinue |
        Where-Object { Select-String -LiteralPath $_.FullName -Pattern $marker -SimpleMatch -Quiet } |
        ForEach-Object {
            Remove-Item -LiteralPath $_.DirectoryName -Recurse -Force -ErrorAction SilentlyContinue
            if (Test-Path -LiteralPath $_.DirectoryName) { Write-Warning "$($_.DirectoryName) is in use; close all editors and rerun"; $rc = 1 }
            else { Fixed "removed $($_.DirectoryName)" }
        }

    # Dropped files. Temp\<n> are per-session temp dirs on RDP hosts.
    @(
        "$profileDir\.config\smt.cmd"
        "$profileDir\.config\smtk"
        "$profileDir\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\sysmon.cmd"
    ) + @(Get-ChildItem -LiteralPath "$profileDir\AppData\Local\Temp" -Filter .stk_* -Recurse -Depth 1 -Force -File -ErrorAction SilentlyContinue |
        ForEach-Object FullName) |
        Where-Object { Test-Path -LiteralPath $_ } |
        ForEach-Object {
            Remove-Item -LiteralPath $_ -Force -ErrorAction SilentlyContinue
            if (Test-Path -LiteralPath $_) { Write-Warning "could not remove $_"; $rc = 1 }
            else { Fixed "removed $_" }
        }

    # Attacker key. It's appended without a leading newline, so it may share a line with a real key.
    # Latin-1 round-trips bytes 1:1, so the file keeps its encoding; \x00 handles UTF-16, where newline is 0A 00.
    $authKeys = "$profileDir\.ssh\authorized_keys"
    if (-not (Test-Path -LiteralPath $authKeys)) { continue }
    $text = $latin1.GetString([IO.File]::ReadAllBytes($authKeys))
    if ($text.Contains($key)) {
        $k = [regex]::Escape($key)
        try {
            [IO.File]::WriteAllBytes($authKeys, $latin1.GetBytes(($text -replace "(?m)(?<=^|\x00)$k\n", '' -replace $k, '')))
            Fixed "removed key from $authKeys"
        } catch { Write-Warning "key still in ${authKeys}: $_"; $rc = 1 }
    }
}

# Report
$left = Get-CimInstance Win32_Process | Where-Object CommandLine -match $procs
if ($left) { Write-Warning "tunnel processes still running: $($left.ProcessId -join ', ')"; $rc = 1 }
if ($rc) {
    Write-Warning 'incomplete: see warnings above'
} elseif ($found) {
    if (Get-NetTCPConnection -LocalPort 22 -State Listen -ErrorAction SilentlyContinue) {
        'note: something listens on localhost:22; the tunnel exposed it'
    }
    'done: backdoor removed'
} else {
    'clean: no backdoor found'
}
exit $rc
