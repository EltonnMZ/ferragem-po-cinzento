param(
  [int]$Port = 4173
)

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootFull = [System.IO.Path]::GetFullPath($Root)
$Prefix = "http://localhost:$Port/"

$ContentTypes = @{
  ".html" = "text/html; charset=utf-8"
  ".js" = "text/javascript; charset=utf-8"
  ".css" = "text/css; charset=utf-8"
  ".json" = "application/json; charset=utf-8"
  ".webmanifest" = "application/manifest+json; charset=utf-8"
  ".jpg" = "image/jpeg"
  ".jpeg" = "image/jpeg"
  ".png" = "image/png"
  ".svg" = "image/svg+xml"
  ".ico" = "image/x-icon"
  ".sql" = "text/plain; charset=utf-8"
  ".md" = "text/markdown; charset=utf-8"
}

function Write-Response {
  param(
    [System.Net.Sockets.NetworkStream]$Stream,
    [int]$StatusCode,
    [string]$StatusText,
    [string]$ContentType,
    [byte[]]$Body
  )

  $Header = "HTTP/1.1 $StatusCode $StatusText`r`nContent-Type: $ContentType`r`nContent-Length: $($Body.Length)`r`nConnection: close`r`nCache-Control: no-cache`r`n`r`n"
  $HeaderBytes = [System.Text.Encoding]::ASCII.GetBytes($Header)
  $Stream.Write($HeaderBytes, 0, $HeaderBytes.Length)
  $Stream.Write($Body, 0, $Body.Length)
}

function Write-TextResponse {
  param(
    [System.Net.Sockets.NetworkStream]$Stream,
    [int]$StatusCode,
    [string]$StatusText,
    [string]$Message
  )

  $Body = [System.Text.Encoding]::UTF8.GetBytes($Message)
  Write-Response -Stream $Stream -StatusCode $StatusCode -StatusText $StatusText -ContentType "text/plain; charset=utf-8" -Body $Body
}

$Address = [System.Net.IPAddress]::Parse("127.0.0.1")
$Listener = [System.Net.Sockets.TcpListener]::new($Address, $Port)

try {
  $Listener.Start()
} catch {
  Write-Host ""
  Write-Host "Não consegui iniciar o servidor em $Prefix"
  Write-Host "Detalhe: $($_.Exception.Message)"
  Write-Host ""
  Write-Host "Se já houver outro servidor aberto, feche a janela antiga ou rode:"
  Write-Host "powershell -ExecutionPolicy Bypass -File servidor-local.ps1 -Port 4174"
  exit 1
}

Write-Host ""
Write-Host "Ferragem Pó Cinzento está a rodar em:"
Write-Host $Prefix
Write-Host ""
Write-Host "Abra esse endereço no navegador."
Write-Host "Para parar o servidor, pressione Ctrl + C nesta janela."
Write-Host ""

try {
  while ($true) {
    $Client = $Listener.AcceptTcpClient()
    $Stream = $Client.GetStream()

    try {
      $Buffer = New-Object byte[] 8192
      $Read = $Stream.Read($Buffer, 0, $Buffer.Length)
      if ($Read -le 0) {
        $Client.Close()
        continue
      }

      $RequestText = [System.Text.Encoding]::ASCII.GetString($Buffer, 0, $Read)
      $FirstLine = ($RequestText -split "`r?`n")[0]
      $Parts = $FirstLine -split " "

      if ($Parts.Length -lt 2) {
        Write-TextResponse -Stream $Stream -StatusCode 400 -StatusText "Bad Request" -Message "Pedido inválido."
        $Client.Close()
        continue
      }

      $RequestPath = $Parts[1].Split("?")[0].TrimStart("/")
      $RequestPath = [System.Uri]::UnescapeDataString($RequestPath)

      if ([string]::IsNullOrWhiteSpace($RequestPath)) {
        $RequestPath = "index.html"
      }

      $Candidate = Join-Path $RootFull $RequestPath
      $FullPath = [System.IO.Path]::GetFullPath($Candidate)

      if (-not $FullPath.StartsWith($RootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        Write-TextResponse -Stream $Stream -StatusCode 403 -StatusText "Forbidden" -Message "Acesso negado."
        $Client.Close()
        continue
      }

      if (-not (Test-Path -LiteralPath $FullPath -PathType Leaf)) {
        Write-TextResponse -Stream $Stream -StatusCode 404 -StatusText "Not Found" -Message "Arquivo não encontrado."
        $Client.Close()
        continue
      }

      $Body = [System.IO.File]::ReadAllBytes($FullPath)
      $Extension = [System.IO.Path]::GetExtension($FullPath).ToLowerInvariant()
      $ContentType = if ($ContentTypes.ContainsKey($Extension)) { $ContentTypes[$Extension] } else { "application/octet-stream" }
      Write-Response -Stream $Stream -StatusCode 200 -StatusText "OK" -ContentType $ContentType -Body $Body
    } catch {
      if ($Stream.CanWrite) {
        Write-TextResponse -Stream $Stream -StatusCode 500 -StatusText "Internal Server Error" -Message "Erro interno do servidor."
      }
    } finally {
      $Stream.Close()
      $Client.Close()
    }
  }
} finally {
  $Listener.Stop()
}
