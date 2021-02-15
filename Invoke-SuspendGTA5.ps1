# this has been adapted from https://web.archive.org/web/20201111195553/https://gist.github.com/19WAS85/5424431

[CmdletBinding()]
Param(
  [int] $Port = 8080,
  [switch] $LocalOnly
)

. "$PSScriptRoot\util\http.ps1"
. "$PSScriptRoot\util\win32.ps1"

function main {
  InjectSuspendMethodsIntoScope

  $indexPage = Get-Content ("$PSScriptRoot\index.html")

  try {
    $script:shouldQuit = $false

    $routes = @(
      @{
        Handler = {
          Param($req, $res)

          SetResponseContent $res $indexPage
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