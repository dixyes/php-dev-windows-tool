
$script:proxy = ${env:https_proxy}
$script:workdir = "C:\php"
function downloadrelpath {
    param (
        $Path,
        $Hash
    )

    if (Test-Path ($script:workdir + "/download/$Path") -PathType Leaf) {
        if ($Hash -Eq 'SKIP' -Or $Hash -Eq (Get-FileHash -Algorithm SHA256 ($script:workdir + "/download/$Path")).Hash.ToLower()) {
            Write-Host "$path is already provided" -ForegroundColor White
            return
        }
    }

    Invoke-WebRequest `
        -Uri ('https://windows.php.net/downloads/releases/' + $Path) `
        -UseBasicParsing `
        -OutFile ($script:workdir + "/download/$Path") `
        -Proxy $script:proxy
    
    if ($Hash -Ne 'SKIP' -And $Hash -Ne (Get-FileHash -Algorithm SHA256 ($script:workdir + "/download/$Path")).Hash.ToLower()) {
        throw "failed to download $path"
    }
}

$script:shapp = New-Object -ComObject 'Shell.Application'

function fetchversion {
    [CmdletBinding()]
    param (
        $Ver,
        $Meta
    )
    $dir_base = $script:workdir + '\' + $Ver.Replace('.', '')

    Write-Host "fetching PHP $ver" -ForegroundColor White
    
    Write-Host "fetching varient $Ver $k source" -ForegroundColor White
    downloadrelpath -Path $Meta.source.path -Hash 'SKIP'

    $srcFiles = $script:shapp.NameSpace($script:workdir + '\download\' + $Meta.source.path).Items()
    if ($srcFiles.Count -Eq 1) {
        $dn = $srcFiles.Item(0).Name
        $noPrefix = $false
    } else {
        # no prefix, create that dir and extract into it
        $dn = $Meta.source.path.Split('/')[-1].Replace('.zip', '')
        $noPrefix = $true
    }
    if (-Not (Test-Path "$script:workdir\$dn" -Type Container)) {
        if ($noPrefix) {
            New-Item -ItemType Container -Path "$script:workdir\$dn"
            Expand-Archive -Path ($script:workdir + '\download\' + $Meta.source.path) -DestinationPath "$script:workdir\$dn" -Force
        } else {
            Expand-Archive -Path ($script:workdir + '\download\' + $Meta.source.path) -DestinationPath $script:workdir -Force
        }
    }
    New-Item -Type SymbolicLink -Value "$script:workdir\$dn" -Path "${dir_base}-src" -Force

    foreach ($k in $Meta.Keys) {
        if ($k -match 'n*ts-v[sc]\d+-x64') {
            $dir = $dir_base
            if ($k.Split('-')[0] -Eq 'ts') {
                $dir = $dir_base + 'ts'
            }

            Write-Host "fetching varient $Ver $k binary" -ForegroundColor White
            downloadrelpath -Path $Meta[$k].zip.path -Hash $Meta[$k].zip.sha256

            Write-Host "fetching varient $Ver $k devpack" -ForegroundColor White
            downloadrelpath -Path $Meta[$k].devel_pack.path -Hash $Meta[$k].devel_pack.sha256

            Write-Host "fetching varient $Ver $k dbgpack" -ForegroundColor White
            downloadrelpath -Path $Meta[$k].debug_pack.path -Hash $Meta[$k].debug_pack.sha256

            if (Test-Path $dir -PathType Container) {
                Write-Host "removing old dir $dir" -ForegroundColor White
                Remove-Item $dir -Recurse
            }

            Write-Host "expanding $Ver $k binary" -ForegroundColor White
            New-Item -ItemType Container $dir
            Expand-Archive -DestinationPath $dir -Path ($script:workdir + '\download\' + $Meta[$k].zip.path)

            Write-Host "expanding $Ver $k devpack" -ForegroundColor White
            $sdkFiles = $script:shapp.NameSpace($script:workdir + '\download\' + $Meta[$k].devel_pack.path).Items()
            if ($sdkFiles.Count -Eq 1) {
                $dn = $sdkFiles.Item(0).Name
            } else {
                Write-Host fucked
                throw fucked
            }
            Expand-Archive -DestinationPath $dir -Path ($script:workdir + '\download\' + $Meta[$k].devel_pack.path)
            Move-Item -Path "$dir\$dn" -Destination "$dir\SDK"

            Write-Host "expanding $Ver $k dbgpack" -ForegroundColor White
            Expand-Archive -DestinationPath $dir -Path ($script:workdir + '\download\' + $Meta[$k].debug_pack.path)
            Move-Item -Path "$dir\php_*.pdb" -Destination "$dir\ext"

            Write-Host "genarating ini for $Ver $k" -ForegroundColor White

            $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
            $ini = "extension_dir=$dir\ext`n"
            $ini = $ini + "zend_extension=opcache`nextension=openssl`nextension=curl`nextension=mbstring`nextension=mysqli`nextension=pdo_mysql`nextension=sockets`nextension=fileinfo`n"
            foreach ($ext in @('ffi', 'gd', 'iconv')) {
                if (Test-Path "$dir\ext\php_$ext.dll" -PathType Leaf) {
                    $ini = $ini + "extension=$ext`n"
                }
            }
            [System.IO.File]::WriteAllLines("$dir\php.ini", $ini, $Utf8NoBomEncoding)
        }
    }

    #echo $Meta

    #Invoke-WebRequest -Uri
}


try {
    $release_meta = Invoke-WebRequest -Uri 'https://windows.php.net/downloads/releases/releases.json' -Proxy $script:proxy
} catch {
    Write-Host "Failed to fetch releases meta"
    exit 1
}
#echo $release_meta.Content

$release_meta = ($release_meta.Content | ConvertFrom-Json -AsHashtable)

foreach ($ver in $release_meta.Keys) {
    fetchversion -Meta $release_meta[$ver] -Ver $ver
}