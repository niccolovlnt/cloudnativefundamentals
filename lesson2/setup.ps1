# Prepara l'ambiente per la lezione 2: verifica Docker, scarica kind, kubectl e kubecolor in ~\Downloads\cnf-tools
# e li aggiunge al PATH dell'utente (con alias kubectl -> kubecolor e autocompletion nel profilo). Uso: powershell -ExecutionPolicy Bypass -File setup.ps1
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'   # Invoke-WebRequest molto piu' veloce

# --- 1. Docker ---
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Error "Docker non trovato. Installa Docker Desktop: https://docs.docker.com/desktop/setup/install/windows-install/"
}
docker info *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Error "Docker e' installato ma il motore non risponde. Avvia Docker Desktop e riesegui lo script."
}
Write-Host "Docker OK: $(docker version --format '{{.Server.Version}}')"

# --- 2. Cartella di destinazione ---
$dest = Join-Path ([Environment]::GetFolderPath('UserProfile')) 'Downloads\cnf-tools'
New-Item -ItemType Directory -Force $dest | Out-Null
$arch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'amd64' }

# --- 3. kubectl (con verifica sha256) ---
$kubeVer = (Invoke-RestMethod https://dl.k8s.io/release/stable.txt).Trim()
$kubectl = Join-Path $dest 'kubectl.exe'
Write-Host "Scarico kubectl $kubeVer..."
Invoke-WebRequest "https://dl.k8s.io/release/$kubeVer/bin/windows/$arch/kubectl.exe" -OutFile $kubectl
$expected = (Invoke-RestMethod "https://dl.k8s.io/release/$kubeVer/bin/windows/$arch/kubectl.exe.sha256").Trim()
if ((Get-FileHash $kubectl -Algorithm SHA256).Hash -ne $expected) {
    Remove-Item $kubectl
    Write-Error "Checksum di kubectl non valido, file eliminato."
}

# --- 4. kind ---
$kind = Join-Path $dest 'kind.exe'
Write-Host "Scarico kind..."
Invoke-WebRequest "https://kind.sigs.k8s.io/dl/latest/kind-windows-$arch" -OutFile $kind

# --- 4b. kubecolor (kubectl con output colorato, con verifica sha256) ---
$kcVer = (Invoke-RestMethod https://api.github.com/repos/kubecolor/kubecolor/releases/latest).tag_name.TrimStart('v')
$kcFile = "kubecolor_${kcVer}_windows_$arch.zip"
$kcUrl = "https://github.com/kubecolor/kubecolor/releases/download/v$kcVer"
$tmp = Join-Path ([IO.Path]::GetTempPath()) "kubecolor-$kcVer"
New-Item -ItemType Directory -Force $tmp | Out-Null
Write-Host "Scarico kubecolor $kcVer..."
Invoke-WebRequest "$kcUrl/$kcFile" -OutFile (Join-Path $tmp $kcFile)
$sums = (Invoke-RestMethod "$kcUrl/checksums.txt") -split "`n"
$expected = ($sums | Where-Object { $_ -match "\s$([regex]::Escape($kcFile))\s*$" }) -split '\s+' | Select-Object -First 1
if (-not $expected -or (Get-FileHash (Join-Path $tmp $kcFile) -Algorithm SHA256).Hash -ne $expected) {
    Remove-Item $tmp -Recurse -Force
    Write-Error "Checksum di kubecolor non valido."
}
Expand-Archive (Join-Path $tmp $kcFile) -DestinationPath $tmp -Force
Copy-Item (Join-Path $tmp 'kubecolor.exe') $dest -Force
Remove-Item $tmp -Recurse -Force
$kubecolor = Join-Path $dest 'kubecolor.exe'

# --- 5. PATH (utente, persistente + sessione corrente) ---
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if (($userPath -split ';') -notcontains $dest) {
    [Environment]::SetEnvironmentVariable('Path', ("$dest;$userPath").TrimEnd(';'), 'User')
}
if (($env:Path -split ';') -notcontains $dest) { $env:Path = "$dest;$env:Path" }

# --- 5b. alias kubectl -> kubecolor nel profilo PowerShell (una sola volta) ---
$aliasLine = 'Set-Alias kubectl kubecolor'
if (-not (Test-Path $PROFILE)) { New-Item -ItemType File -Force $PROFILE | Out-Null }
if (-not (Select-String -Path $PROFILE -SimpleMatch -Pattern $aliasLine -Quiet)) { Add-Content $PROFILE $aliasLine }
Set-Alias kubectl kubecolor -Scope Global

# --- 5c. Autocompletion di kubectl (anche per l'alias kubecolor), generata una volta e caricata dal profilo ---
$comp = Join-Path $dest 'kubectl-completion.ps1'
(& $kubectl completion powershell) + "Register-ArgumentCompleter -CommandName 'kubecolor' -ScriptBlock `${__kubectlCompleterBlock}" | Set-Content $comp -Encoding utf8
$compLine = ". `"$comp`""
if (-not (Select-String -Path $PROFILE -SimpleMatch -Pattern $compLine -Quiet)) { Add-Content $PROFILE $compLine }
. $comp

# --- 6. Verifica ---
& $kind version
& $kubectl version --client
& $kubecolor --kubecolor-version
Write-Host "`nFatto!"
