function UserIsAdmin {
  $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
  return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-IpAddresses {
  $addresses = (ipconfig | Select-String 'IPv4 Address')

  if ($addresses) {
    return $addresses | ForEach-Object {
      Write-Verbose $_
      if ($_ -match '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}') {
        if ($Matches[0]) {
          return $Matches[0]
        }
      }

      return $null
    }
  }

  return $null
}

function Get-DnsSuffixes {
  $suffixes = (ipconfig | Select-String "DNS Suffix  . : \S")
  if ($suffixes) {
    return $suffixes | ForEach-Object {
      Write-Verbose $_
      if ($_ -match "[^\d\s]+\.[^\d\s]+$") {
        return $Matches[0]
      }

      return $null
    }
  }

  return $null
}

function Get-IpAddressBindings {
  $ips = Get-IpAddresses
  if ($ips) {
    return $ips | ForEach-Object { "http://$($_):$Port/" }
  }

  throw "Couldn't get IP addresses"
}

function Get-HostnameBindings {
  $suffixes = Get-DnsSuffixes
  if ($suffixes) {
    return $suffixes | ForEach-Object { "http://$($env:ComputerName).$($_):$Port/" }
  }

  throw "Couldn't get DNS suffix"
}

function ConfigureBindings ($listener) {
  $userIsAdmin = UserIsAdmin

  $binding = "http://localhost:$Port/"
  $listener.Prefixes.Add($binding)
  Write-Host "Bound listener to $binding"

  if ($userIsAdmin -and !$LocalOnly) {
    try {
      $bindings = Get-IpAddressBindings
      Write-Verbose "Got IP address bindings '$bindings'"
      foreach ($binding in $bindings) {
        $listener.Prefixes.Add($binding)
        Write-Host "Bound listener to $binding"
      }

      $bindings = Get-HostnameBindings
      Write-Verbose "Got hostname bindings '$bindings'"
      foreach ($binding in $bindings) {
        $listener.Prefixes.Add($binding)
        Write-Host "Bound listener to $binding"
      }
    } catch {
      Write-Error $_

      Write-Host "Continuing with local binding only"
    }
  }
}

function SetResponseContent ($res, $content) {
  if ($content -and $content.Length -gt 0) {
    $buffer = [System.Text.Encoding]::UTF8.GetBytes($content)

    $res.ContentLength64 = $buffer.Length
    $res.OutputStream.Write($buffer, 0, $buffer.Length)
  }
}

function NormalizeQueryString($queryString) {
  $result = @{}
  foreach ($key in $queryString.Keys) {
    $val = $queryString[$key]

    if ($val) {
      try {
        $val = [float]$val
      } catch {
        try {
          if ($val.ToLower() -eq "true") { $val = $true }
          elseif ($val.ToLower() -eq "false") { $val = $false }
        } catch { }
      }
    } else {
      $val = $null
    }

    $result[$key] = $val
  }
  return $result
}

function ProcessRequest($listener, $routes) {
  $context = $listener.GetContext()
  $req = $context.Request
  $res = $context.Response

  $method = $req.HttpMethod
  $rawUrl = $req.RawUrl

  Write-Host "$($req.UserHostAddress) => $method $($rawUrl)" -f 'mag'

  $route = $routes | Where-Object { ($_.Method -eq $method) -and ($rawUrl -eq $_.Path) }
  Write-Verbose "Matched '$rawUrl' to '$($route.Path)'"

  if ($route) {
    $params = NormalizeQueryString $req.QueryString

    $route.Handler.Invoke($req, $res, $params)
  } else {
    $res.StatusCode = 404
    $res.StatusDescription = "Not Found"
  }

  $res.OutputStream.Close()

  Write-Verbose "Returning $($res.StatusCode)"

  if ($script:shouldQuit) {
    $listener.Stop()
    Write-Host "Stopped listener"
  }
}