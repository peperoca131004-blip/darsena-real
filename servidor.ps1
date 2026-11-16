# Seguimiento de disponibilidad - Darsena Real (Urbincasa)
# Servidor local sin dependencias: lee la web de la promocion, guarda historial y sirve el panel.

#   servidor.ps1            -> lee la web y abre el panel en http://localhost:8787
#   servidor.ps1 -SoloLeer  -> lee la web, guarda el historial y termina (lo usa la tarea diaria)
param(
    [int]$Puerto = 8787,
    [switch]$SoloLeer,
    [string]$HoraDiaria = '09:00'
)

$ErrorActionPreference = 'Stop'
$URL_PROMO = 'https://urbincasa.es/es/promocion/darsena-real-1886'
$BASE      = 'https://urbincasa.es'
$Dir       = Split-Path -Parent $MyInvocation.MyCommand.Path
$DirDatos  = Join-Path $Dir 'datos'
$FichHist  = Join-Path $DirDatos 'historial.json'
$FichHtml  = Join-Path $Dir 'index.html'
if (-not (Test-Path $DirDatos)) { New-Item -ItemType Directory -Path $DirDatos | Out-Null }

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Get-Attr([string]$tag, [string]$name) {
    $m = [regex]::Match($tag, "$name=""([^""]*)""")
    if ($m.Success) { return [Net.WebUtility]::HtmlDecode($m.Groups[1].Value) } else { return $null }
}

function Read-Promocion {
    $wc = New-Object Net.WebClient
    $wc.Encoding = [Text.Encoding]::UTF8
    $wc.Headers.Add('User-Agent', 'Mozilla/5.0 (seguimiento disponibilidad)')
    $html = $wc.DownloadString($URL_PROMO)

    # Nombres de fase desde las pestanas
    $nombres = @{}
    foreach ($m in [regex]::Matches($html, 'id="tab3d(bloque\d+)"[^>]*>([^<]+)</button>')) {
        $nombres[$m.Groups[1].Value] = $m.Groups[2].Value.Trim()
    }

    # Secciones de cada fase
    $marcas = [regex]::Matches($html, 'id="bloque3d(bloque\d+)"')
    $fases = @()
    for ($i = 0; $i -lt $marcas.Count; $i++) {
        $id     = $marcas[$i].Groups[1].Value
        $inicio = $marcas[$i].Index
        $fin    = if ($i + 1 -lt $marcas.Count) { $marcas[$i + 1].Index } else { $html.Length }
        $sec    = $html.Substring($inicio, $fin - $inicio)

        $tot  = [regex]::Match($sec, 'Viviendas totales:</span>\s*<span[^>]*>(\d+)<')
        $disp = [regex]::Match($sec, 'Disponibles:</span>\s*<span[^>]*>(\d+)<')

        $viviendas = @()
        foreach ($a in [regex]::Matches($sec, '<area[^>]*data-disponible="1"[^>]*>')) {
            $t = $a.Value
            $url = Get-Attr $t 'data-url'
            $viviendas += [ordered]@{
                codigo      = Get-Attr $t 'rel'
                referencia  = Get-Attr $t 'data-referencia'
                planta      = Get-Attr $t 'data-planta'
                dormitorios = Get-Attr $t 'data-bedrooms'
                banos       = Get-Attr $t 'data-bathrooms'
                superficie  = Get-Attr $t 'data-superficie'
                plano       = Get-Attr $t 'data-planos'
                url         = if ($url) { $BASE + $url } else { $null }
            }
        }

        $nombre = if ($nombres.ContainsKey($id)) { $nombres[$id] } else { $id }
        $total  = if ($tot.Success) { [int]$tot.Groups[1].Value } else { 0 }
        $libres = if ($disp.Success) { [int]$disp.Groups[1].Value } else { $viviendas.Count }

        $fases += [ordered]@{
            id          = $id
            nombre      = $nombre
            total       = $total
            disponibles = $libres
            viviendas   = $viviendas
        }
    }
    if ($fases.Count -eq 0) { throw 'No se han encontrado fases en la pagina (puede que haya cambiado su estructura).' }
    return ,$fases
}

# ---------- Historial ----------
$script:Hist = [ordered]@{ ultimaLectura = $null; ultimoError = $null; actual = $null; registros = @(); cambios = @() }

# Se recarga desde disco antes de cada uso: la tarea diaria y el panel pueden escribir el mismo fichero.
function Read-Historial {
    if (-not (Test-Path $FichHist)) { return }
    try {
        $h = [IO.File]::ReadAllText($FichHist, [Text.Encoding]::UTF8) | ConvertFrom-Json
        $script:Hist.ultimaLectura = $h.ultimaLectura
        $script:Hist.ultimoError   = $h.ultimoError
        $script:Hist.actual        = $h.actual
        $script:Hist.registros     = @($h.registros | Where-Object { $_ })
        $script:Hist.cambios       = @($h.cambios | Where-Object { $_ })
    } catch { Write-Host "Aviso: no se pudo leer el historial ($($_.Exception.Message))." }
}

function Save-Historial {
    $json = ConvertTo-Json -InputObject $script:Hist -Depth 10
    [IO.File]::WriteAllText($FichHist, $json, (New-Object Text.UTF8Encoding($false)))
}

function Update-Datos {
    $ahora = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss')
    Read-Historial
    try {
        $fases = Read-Promocion
    } catch {
        $script:Hist.ultimoError = "$ahora - $($_.Exception.Message)"
        Write-Host "[$ahora] Error al leer: $($_.Exception.Message)"
        Save-Historial
        return
    }
    $script:Hist.ultimoError = $null

    # Detectar cambios respecto a la lectura anterior
    $previo = $script:Hist.actual
    if ($previo) {
        foreach ($f in $fases) {
            $pf = @($previo | Where-Object { $_.id -eq $f.id }) | Select-Object -First 1
            if (-not $pf) { continue }
            $antes    = @($pf.viviendas | Where-Object { $_ } | ForEach-Object { $_.codigo })
            $ahoraCod = @($f.viviendas  | Where-Object { $_ } | ForEach-Object { $_.codigo })
            foreach ($c in $antes)    { if ($ahoraCod -notcontains $c) { $script:Hist.cambios += [ordered]@{ fecha = $ahora; fase = $f.nombre; vivienda = $c; tipo = 'ya no disponible' } } }
            foreach ($c in $ahoraCod) { if ($antes -notcontains $c)    { $script:Hist.cambios += [ordered]@{ fecha = $ahora; fase = $f.nombre; vivienda = $c; tipo = 'nueva disponible' } } }
            if ([int]$pf.disponibles -ne $f.disponibles -and $antes.Count -eq $ahoraCod.Count) {
                $script:Hist.cambios += [ordered]@{ fecha = $ahora; fase = $f.nombre; vivienda = ''; tipo = "disponibles $($pf.disponibles) -> $($f.disponibles)" }
            }
        }
    }

    # Guardar un registro solo si cambian los numeros (o es el primero)
    $resumen = @($fases | ForEach-Object { [ordered]@{ id = $_.id; nombre = $_.nombre; total = $_.total; disponibles = $_.disponibles } })
    $firma   = ($resumen | ForEach-Object { "$($_.id):$($_.disponibles)/$($_.total)" }) -join '|'
    $ultimo  = @($script:Hist.registros) | Select-Object -Last 1
    $firmaUlt = if ($ultimo) { (@($ultimo.fases) | ForEach-Object { "$($_.id):$($_.disponibles)/$($_.total)" }) -join '|' } else { '' }
    if ($firma -ne $firmaUlt) {
        $script:Hist.registros += [ordered]@{ fecha = $ahora; fases = $resumen }
    }

    $script:Hist.actual        = $fases
    $script:Hist.ultimaLectura = $ahora
    Save-Historial
    $libres = 0; foreach ($f in $fases) { $libres += $f.disponibles }
    Write-Host "[$ahora] Lectura correcta: $libres viviendas disponibles en $($fases.Count) fases."
}

function Send-Respuesta($ctx, [string]$cuerpo, [string]$tipo, [int]$codigo = 200) {
    $bytes = [Text.Encoding]::UTF8.GetBytes($cuerpo)
    $ctx.Response.StatusCode = $codigo
    $ctx.Response.ContentType = $tipo
    $ctx.Response.Headers.Add('Cache-Control', 'no-store')
    $ctx.Response.ContentLength64 = $bytes.Length
    $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
    $ctx.Response.OutputStream.Close()
}

function Get-Estado {
    Read-Historial
    $o = [ordered]@{
        fuente        = $URL_PROMO
        horaDiaria    = $HoraDiaria
        ultimaLectura = $script:Hist.ultimaLectura
        ultimoError   = $script:Hist.ultimoError
        actual        = $script:Hist.actual
        registros     = $script:Hist.registros
        cambios       = $script:Hist.cambios
    }
    return (ConvertTo-Json -InputObject $o -Depth 10 -Compress)
}

# ---------- Arranque ----------
Update-Datos
if ($SoloLeer) { exit 0 }

$listener = New-Object Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Puerto/")
$listener.Start()
Write-Host ""
Write-Host "Panel disponible en http://localhost:$Puerto/  (Ctrl+C para cerrar)"
Write-Host "La lectura diaria la hace la tarea programada de Windows a las $HoraDiaria."

try {
    while ($listener.IsListening) {
        $tarea = $listener.GetContextAsync()
        while (-not $tarea.Wait(1000)) { }
        $ctx = $tarea.Result
        try {
            switch ($ctx.Request.Url.AbsolutePath) {
                '/'               { Send-Respuesta $ctx ([IO.File]::ReadAllText($FichHtml, [Text.Encoding]::UTF8)) 'text/html; charset=utf-8' }
                { $_ -in '/logo.png', '/foto.jpg' } {
                    $b = [IO.File]::ReadAllBytes((Join-Path $Dir $_.TrimStart('/')))
                    $ctx.Response.ContentType = if ($_ -like '*.png') { 'image/png' } else { 'image/jpeg' }
                    $ctx.Response.ContentLength64 = $b.Length
                    $ctx.Response.OutputStream.Write($b, 0, $b.Length); $ctx.Response.OutputStream.Close()
                }
                '/api/estado'     { Send-Respuesta $ctx (Get-Estado) 'application/json; charset=utf-8' }
                '/api/actualizar' { Update-Datos; Send-Respuesta $ctx (Get-Estado) 'application/json; charset=utf-8' }
                default           { Send-Respuesta $ctx 'No encontrado' 'text/plain' 404 }
            }
        } catch {
            try { Send-Respuesta $ctx "Error: $($_.Exception.Message)" 'text/plain' 500 } catch {}
        }
    }
} finally {
    $listener.Stop()
}
