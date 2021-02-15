function InjectSuspendMethodsIntoScope {
  Add-Type @"
  using System;
  using System.Runtime.InteropServices;

  public static class Win32
  {
    [DllImport("kernel32.dll")]
    public static extern bool DebugActiveProcess(int processId);

    [DllImport("kernel32.dll")]
    public static extern bool DebugActiveProcessStop(int processId);
  }
"@
}

function Suspend {
  Param(
    [string] $processName
  )

  $ret = $false

  $processes = Get-Process | Where-Object { $_.ProcessName -Like "*$processName*" }

  foreach ($process in $processes) {
    $processId = $process.Id
    [Win32]::DebugActiveProcess($processId) | Out-Null
    $ret = $true
  }

  Write-Verbose "Processes suspended: $($processes.Length)"

  return $ret
}

function Unsuspend {
  Param(
    [string] $processName
  )

  $ret = $false

  $processes = Get-Process | Where-Object { $_.ProcessName -Like "*$processName*" }

  foreach ($process in $processes) {
    $processId = $process.Id
    [Win32]::DebugActiveProcessStop($processId) | Out-Null
    $ret = $true
  }

  Write-Verbose "Processes unsuspended: $($processes.Length)"

  return $ret
}