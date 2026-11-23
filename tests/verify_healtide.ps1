$ErrorActionPreference = "Continue"

$wow = "C:\Jeux\World of Warcraft\_forever_"
$addon = Join-Path $wow "Interface\AddOns\HealTide"
$lua = Join-Path $addon "HealTide.lua"
$toc = Join-Path $addon "HealTide.toc"

Write-Output "=== Addon files ==="
Get-ChildItem $addon -ErrorAction SilentlyContinue | Select-Object Name, Length, LastWriteTime | Format-Table -AutoSize | Out-String -Width 200

Write-Output "=== TOC ==="
if (Test-Path $toc) {
    Select-String -Path $toc -Pattern '^## (Interface|Title|Version|SavedVariables)' | ForEach-Object { $_.Line }
} else { Write-Output "Missing TOC: $toc" }

Write-Output "=== Syntax ==="
$luac = Get-Command luac -ErrorAction SilentlyContinue
if (-not $luac) {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    $luac = Get-Command luac -ErrorAction SilentlyContinue
}
if ($luac -and (Test-Path $lua)) {
    & $luac.Source -p $lua 2>&1
    if ($LASTEXITCODE -eq 0) { Write-Output "SYNTAX OK" } else { Write-Output "SYNTAX ERROR" }
} else { Write-Output "luac not found or addon missing" }

Write-Output "=== Saved variables ==="
$sv = Get-ChildItem (Join-Path $wow "WTF\Account") -Recurse -Filter "HealTide.lua" -ErrorAction SilentlyContinue |
      Where-Object { $_.FullName -notmatch '\\Interface\\' } |
      Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($sv) {
    Write-Output ("File: " + $sv.FullName)
    Write-Output ("Last write: " + $sv.LastWriteTime)
    Select-String -Path $sv.FullName -Pattern 'HealTideDB|loaded|interface|calc|clampMode|twoCalculators|events|casts|predictions|cards|lastError' |
        ForEach-Object { $_.Line.Trim() }
} else {
    Write-Output "No HealTide.lua saved-variables file yet. Has the game been reloaded?"
}

Write-Output "=== HealTide errors ==="
$errors = Get-ChildItem (Join-Path $wow "Errors") -Recurse -File -ErrorAction SilentlyContinue |
          Sort-Object LastWriteTime -Descending | Select-Object -First 20
$found = $false
foreach ($file in $errors) {
    $matches = Select-String -Path $file.FullName -Pattern 'HealTide' -ErrorAction SilentlyContinue
    if ($matches) {
        $found = $true
        Write-Output ("--- " + $file.FullName + " ---")
        $matches | ForEach-Object { $_.Line }
    }
}
if (-not $found) { Write-Output "No HealTide errors in the last 20 error files." }
