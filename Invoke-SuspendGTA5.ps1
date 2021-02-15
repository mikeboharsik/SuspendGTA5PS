# this has been adapted from https://web.archive.org/web/20201111195553/https://gist.github.com/19WAS85/5424431

[CmdletBinding()]
Param(
  [int] $Port = 8080,
  [switch] $LocalOnly
)

function UserIsAdmin {
  $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
  return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

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
        }
        Method = "GET"
        Path = "/"
      },
      @{
        Handler = {
          Param($req, $res)

          $script:shouldQuit = $true;
        }
        Method = "GET"
        Path = "/quit"
      },
      @{
        Handler = {
          Param($req, $res, $params)
            
          Suspend "discord"
          Start-Sleep -Seconds 15
          Unsuspend "discord"
        }
        Method = "GET"
        Path = "/suspend"
      }
    )

    $listener = [System.Net.HttpListener]::New() 
    
    ConfigureBindings $listener

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