function Get-IpAddress {
  if ((ipconfig | Select-String 'IPv4 Address') -match '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}') {
    return $Matches[0]
  }

  return $null
}

function Get-DnsSuffix {
  if ((ipconfig | Select-String ".com") -Match "\S+\.com") {
    return $Matches[0]
  }

  return $null
}

function Get-IpAddressBinding {
  $ip = Get-IpAddress
  if ($ip) {
    return "http://$($ip):$Port/"
  }

  throw "Couldn't get IP address"
}

function Get-HostnameBinding {
  $suffix = Get-DnsSuffix
  if ($suffix) {
    return "http://$($env:ComputerName).$($suffix):$Port/"
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
      $binding = Get-HostnameBinding
      $listener.Prefixes.Add($binding)
      Write-Host "Bound listener to $binding"

      $binding = Get-IpAddressBinding
      $listener.Prefixes.Add($binding)
      Write-Host "Bound listener to $binding"
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

  $route = $routes | Where-Object { ($_.Method -eq $method) -and ($rawUrl -Match $_.Path) }
  Write-Verbose "Matched '$rawUrl' to '$($route.Path)'"

  if ($route) {
    $params = NormalizeQueryString $req.QueryString

    $route.Handler.Invoke($req, $res, $params)
  } else {
    $res.StatusCode = 404
    $res.StatusDescription = "Not Found"
  }

  $res.OutputStream.Close()

  if ($script:shouldQuit) {
    $listener.Stop()
    Write-Host "Stopped listener"
  }
}