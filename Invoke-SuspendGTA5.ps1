# this has been adapted from https://web.archive.org/web/20201111195553/https://gist.github.com/19WAS85/5424431

<#
.SYNOPSIS
  Facilitates the suspension and unsuspension of the GTA5.exe process

.DESCRIPTION
  Runs an HTTP listener that allows Win32 API functions to be invoked
  either by the user running on localhost or optionally via another
  device on the network, e.g. a phone.

.LINK
 https://github.com/mikeboharsik/SuspendGTA5PS

.PARAMETER Port
  Specifies the port on which to listen for HTTP requests, defaults
  to 8080

.PARAMETER LocalOnly
  If set, skips attempting to bind to network-accessible IP addresses
  and hostnames

.EXAMPLE
  .\Invoke-SuspendGTA5.ps1
  Default behavior that runs on localhost:8080 and tries to bind
  to hostnames if running in an administrator context
#>

[CmdletBinding()]
Param(
  [int] $Port = 8080,
  [switch] $LocalOnly
)

. "$PSScriptRoot\util\http.ps1"
. "$PSScriptRoot\util\win32.ps1"

function main {
  InjectSuspendMethodsIntoScope

  try {
    $script:shouldQuit = $false

    $routes = @(
      @{
        Handler = {
          Param($req, $res)

          SetResponseContent $res (Get-Content "$PSScriptRoot\index.html")
        }
        Method = "GET"
        Path = "/"
      },
      @{
        Handler = {
          Param($req, $res)

          $script:shouldQuit = $true
        }
        Method = "POST"
        Path = "/quit"
      },
      @{
        Handler = {
          Param($req, $res, $params)
            
          if (Suspend "gta5") {
            Start-Sleep -Seconds 15
            Unsuspend "gta5"
          } else {
            $res.StatusCode = 404;
            SetResponseContent $res "Couldn't find process to suspend"
          }
        }
        Method = "POST"
        Path = "/suspend"
      }
    )

    $listener = [System.Net.HttpListener]::New() 
    
    ConfigureBindings $listener

    Write-Verbose "Registered routes: $(($routes | ForEach-Object { Select-Object -InputObject $_ -ExpandProperty Path }) | ConvertTo-Json)"

    $listener.Start()

    # warm up the listener
    Start-Job -ScriptBlock { Invoke-WebRequest -Uri "http://localhost:8080" } | Out-Null

    while ($listener.IsListening) {
      ProcessRequest $listener $routes
    }
  } catch {
    throw $_
  } finally {
    $listener.Stop()
  }
}

main