param(
    [string]$ProjectId = $env:CF_PROJECT_ID,
    [string]$ApiToken = $(if ($env:CF_API_TOKEN) { $env:CF_API_TOKEN } elseif ($env:CF_API_KEY) { $env:CF_API_KEY } else { "" }),
    [string]$GameVersion = $(if ($env:CF_GAME_VERSION) { $env:CF_GAME_VERSION } else { "1.60.1" }),
    [string]$ReleaseType = "release",
    [switch]$ListVersions
)

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$base = "https://wow.curseforge.com"

if (-not $ApiToken) {
    throw "Set CF_API_TOKEN (or CF_API_KEY, or pass -ApiToken). Create a token at https://www.curseforge.com/account/api-tokens"
}

if ($ListVersions) {
    $json = & curl.exe -sS -H "X-Api-Token: $ApiToken" "$base/api/game/versions"
    $versions = $json | ConvertFrom-Json
    $versions |
        Where-Object { $_.name -match '1\.60|Forever' } |
        Select-Object id, name, gameVersionTypeID |
        Format-Table -AutoSize
    Write-Output "Use the exact name with -GameVersion, or the id in the website upload form."
    exit 0
}

if (-not $ProjectId) {
    throw "Set CF_PROJECT_ID (or pass -ProjectId). It is the number in the project overview URL."
}

$toc = Join-Path $root "HealTide.toc"
$line = Select-String -Path $toc -Pattern '^## Version:\s*(.+)$' | Select-Object -First 1
if (-not $line) { throw "No ## Version line in HealTide.toc" }
$version = $line.Matches.Groups[1].Value.Trim()
$zip = Join-Path $root ("dist\HealTide-" + $version + ".zip")

& (Join-Path $root "build.ps1")
if (-not (Test-Path $zip)) { throw "Build failed: $zip not found" }

$changelog = if (Test-Path (Join-Path $root "CHANGELOG.md")) { Get-Content (Join-Path $root "CHANGELOG.md") -Raw } else { "Release $version" }
$metadata = @{
    changelog = $changelog
    changelogType = "markdown"
    displayName = $version
    releaseType = $ReleaseType
    gameVersionNames = @($GameVersion)
} | ConvertTo-Json -Compress

$metaFile = Join-Path $env:TEMP ("healtide-cf-" + [guid]::NewGuid().ToString("N") + ".json")
$utf8 = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($metaFile, $metadata, $utf8)

try {
    Write-Output "Uploading $zip to project $ProjectId (game version $GameVersion, $ReleaseType)..."
    $response = & curl.exe -sS --fail-with-body -X POST `
        -H "X-Api-Token: $ApiToken" `
        -F "metadata=<$metaFile" `
        -F "file=@$zip" `
        "$base/api/projects/$ProjectId/upload-file"
    if ($LASTEXITCODE -ne 0) { throw "CurseForge upload failed (HTTP error)." }
    Write-Output $response
    $json = ($response -join "") | ConvertFrom-Json
    if ($json.id) {
        Write-Output "Upload accepted (file id $($json.id)). Check the project's Files page and release the file if needed."
    } else {
        throw "No file id returned. Try -ListVersions and pass the exact game version name, or upload the zip manually."
    }
} finally {
    Remove-Item $metaFile -Force -ErrorAction SilentlyContinue
}
