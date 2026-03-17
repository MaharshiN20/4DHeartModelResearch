param(
    [Parameter(Mandatory = $true)]
    [string]$LocalEchoNetDir,

    [string]$RemoteUser = "mnaik",
    [string]$RemoteHost = "login.expanse.sdsc.edu",
    [string]$RemoteDataDir = "/home/mnaik/expanse/data",
    [string]$SshKeyPath = "",
    [int]$SshPort = 22,
    [switch]$OpenShell,
    [switch]$UseArchive
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $LocalEchoNetDir)) {
    throw "Local path does not exist: $LocalEchoNetDir"
}

$resolvedKeyPath = ""
if ($SshKeyPath -ne "") {
    if (-not (Test-Path -LiteralPath $SshKeyPath)) {
        throw "SSH key path does not exist: $SshKeyPath"
    }
    $resolvedKeyPath = (Resolve-Path -LiteralPath $SshKeyPath).Path
}

$resolvedLocalDir = (Resolve-Path -LiteralPath $LocalEchoNetDir).Path
$datasetName = Split-Path -Leaf $resolvedLocalDir

if ($datasetName -ne "EchoNet-Dynamic") {
    Write-Host "Warning: folder name is '$datasetName' (expected 'EchoNet-Dynamic'). Continuing..." -ForegroundColor Yellow
}

$parentDir = Split-Path -Parent $resolvedLocalDir
$childName = Split-Path -Leaf $resolvedLocalDir
$target = "$RemoteUser@$RemoteHost"

$sshArgs = @()
if ($resolvedKeyPath -ne "") {
    $sshArgs += "-i"
    $sshArgs += $resolvedKeyPath
}
if ($SshPort -ne 22) {
    $sshArgs += "-p"
    $sshArgs += "$SshPort"
}

$scpArgs = @()
if ($resolvedKeyPath -ne "") {
    $scpArgs += "-i"
    $scpArgs += $resolvedKeyPath
}
if ($SshPort -ne 22) {
    $scpArgs += "-P"
    $scpArgs += "$SshPort"
}

Write-Host "Ensuring remote directory exists: $RemoteDataDir" -ForegroundColor Cyan
& ssh @sshArgs $target "mkdir -p '$RemoteDataDir'"

if ($UseArchive) {
    $archivePath = Join-Path $env:TEMP "$datasetName.tar.gz"

    Write-Host "Creating archive: $archivePath" -ForegroundColor Cyan
    if (Test-Path -LiteralPath $archivePath) {
        Remove-Item -LiteralPath $archivePath -Force
    }

    $tarCmd = Get-Command tar -ErrorAction SilentlyContinue
    if (-not $tarCmd) {
        throw "tar was not found on this Windows machine. Re-run without -UseArchive to use direct scp folder upload."
    }

    # Pack from parent so the top-level folder name is preserved.
    & tar -czf "$archivePath" -C "$parentDir" "$childName"

    Write-Host "Uploading archive to Expanse..." -ForegroundColor Cyan
    & scp @scpArgs "$archivePath" "${target}:$RemoteDataDir/"

    Write-Host "Extracting archive on Expanse..." -ForegroundColor Cyan
    & ssh @sshArgs $target "set -e; tar -xzf '$RemoteDataDir/$datasetName.tar.gz' -C '$RemoteDataDir'; rm -f '$RemoteDataDir/$datasetName.tar.gz'"
}
else {
    Write-Host "Uploading folder directly to Expanse (reliable mode)..." -ForegroundColor Cyan
    & scp @scpArgs -r "$resolvedLocalDir" "${target}:$RemoteDataDir/"
}

Write-Host "Verifying upload..." -ForegroundColor Cyan
& ssh @sshArgs $target "ls -lah '$RemoteDataDir/$datasetName' | sed -n '1,20p'"

Write-Host "Done." -ForegroundColor Green
Write-Host "Use this for training:" -ForegroundColor Green
Write-Host "--echo_dir=$RemoteDataDir/$datasetName" -ForegroundColor Green

if ($OpenShell) {
    Write-Host "Opening SSH shell..." -ForegroundColor Cyan
    & ssh @sshArgs $target
}
