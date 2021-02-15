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

  $processes = Get-Process | Where-Object { $_.ProcessName -Like "*$processName*" }

  foreach ($process in $processes) {
    $processId = $process.Id
    [Win32]::DebugActiveProcess($processId) | Out-Null
  }

  Write-Host "Processes suspended: $($processes.Length)"
}

function Unsuspend {
  Param(
    [string] $processName
  )

  $processes = Get-Process | Where-Object { $_.ProcessName -Like "*$processName*" }

  foreach ($process in $processes) {
    $processId = $process.Id
    [Win32]::DebugActiveProcessStop($processId) | Out-Null
  }

  Write-Host "Processes unsuspended: $($processes.Length)"
}