
param (
    [string]$phpver = '8.3',
    [string]$vcver = "vs16"
)

$script:workdir = "C:\php"

$proxy = ([System.Net.WebRequest]::GetSystemWebproxy()).GetProxy(${env:https_proxy})

$scriptPath = Split-Path -parent $MyInvocation.MyCommand.Definition
. "$scriptPath\utils.ps1" -ToolName "fetcher" -MaxTry 3 -Proxy $proxy

$arch = "x64"
$stagingOrStable = "stable"

info "fetching deps for $phpver"

$uri = "https://windows.php.net/downloads/php-sdk/deps/series/packages-${phpver}-${vcver}-${arch}-${stagingOrStable}.txt"
info "fetching series from ${uri}"
$series = (fetchpage $uri).Content

$files = @($series.Split()) -match '.+\.zip$'

foreach ($filename in $files) {
    if(Test-Path ($script:workdir + "\download\deps\${filename}")){
        info "skipping ${filename}"
        continue
    }
    info "fetching ${filename}"
    $ret = dlwithhash -Uri "https://windows.php.net/downloads/php-sdk/deps/${vcver}/${arch}/${filename}" -Dest ($script:workdir + "\download\deps\${filename}")
    if(!$ret){
        err "failed fetching ${filename}"
    }
}

Remove-Item -Recurse -Path ($script:workdir + "\deps." + $phpver.Replace('.',''))

foreach ($filename in $files) {
    info "unzipping ${filename}"
    Expand-Archive "download\deps\${filename}" -Destination ($script:workdir + "\deps." + $phpver.Replace('.','')) -Force
}
