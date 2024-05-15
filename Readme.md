# tools for prepare windows php development environment

## usage

```powershell
./update.ps1
./deps.ps1
```

by default, the workdir is in C:\php, you may change it in scripts

for extension development:

first, run sdk cmd

```cmd
C:\php\php-sdk-binary-tools\phpsdk-vs16-x64.bat
```

in that cmd window:

```cmd
cd C:\path\to\extension\dir
C:\php\83ts\SDK\phpize.bat
configure.bat --enable-someext=shared --with-prefix=C:\php\83ts --with-debug-pack --enable-some-other-options
nmake
nmake install
C:\php\83ts\php.exe -dextension=someext sometest.php
```
