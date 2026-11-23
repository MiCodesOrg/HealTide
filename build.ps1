$ErrorActionPreference = "Stop"

$root = $PSScriptRoot
$toc = Join-Path $root "HealTide.toc"
$lua = Join-Path $root "HealTide.lua"

if (-not (Test-Path $toc)) { throw "Missing $toc" }
if (-not (Test-Path $lua)) { throw "Missing $lua" }

$versionLine = Select-String -Path $toc -Pattern '^## Version:\s*(.+)$' | Select-Object -First 1
if (-not $versionLine) { throw "No ## Version line in HealTide.toc" }
$version = $versionLine.Matches.Groups[1].Value.Trim()

$dist = Join-Path $root "dist"
$pkg = Join-Path $dist "HealTide"
$zip = Join-Path $dist ("HealTide-" + $version + ".zip")

if (Test-Path $dist) { Remove-Item $dist -Recurse -Force }
New-Item -ItemType Directory -Path $pkg -Force | Out-Null

Copy-Item $toc $pkg
Copy-Item $lua $pkg
$readme = Join-Path $root "README_FR.md"
if (Test-Path $readme) { Copy-Item $readme $pkg }

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::Open($zip, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    Get-ChildItem $pkg -File | ForEach-Object {
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $archive, $_.FullName, ("HealTide/" + $_.Name),
            [System.IO.Compression.CompressionLevel]::Optimal
        ) | Out-Null
    }
} finally {
    $archive.Dispose()
}

$archive = [System.IO.Compression.ZipFile]::OpenRead($zip)
try {
    $names = $archive.Entries | ForEach-Object { $_.FullName }
    if ($names -notcontains "HealTide/HealTide.toc") { throw "Bad package: HealTide/HealTide.toc missing" }
    if ($names -notcontains "HealTide/HealTide.lua") { throw "Bad package: HealTide/HealTide.lua missing" }
} finally {
    $archive.Dispose()
}

Write-Output ("Built " + $zip)
Write-Output ("Version " + $version)
Get-ChildItem $pkg | Select-Object Name, Length | Format-Table -AutoSize
