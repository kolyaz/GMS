# Публикация текущего VERSION на GitHub Releases.
# Установщик не коммитится в git — только asset релиза.
# Нужны: gh auth login, git remote origin.
# Запуск из корня: powershell -File scripts\publish-release.ps1

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$gh = if (Get-Command gh -ErrorAction SilentlyContinue) {
  (Get-Command gh).Source
} elseif (Test-Path "$env:TEMP\gh-cli\bin\gh.exe") {
  "$env:TEMP\gh-cli\bin\gh.exe"
} else {
  throw 'Установи GitHub CLI: https://cli.github.com/'
}

$version = (Get-Content VERSION -Raw).Trim()
if (-not $version) { throw 'Пустой VERSION' }
$tag = "v$version"
$setup = Join-Path $root "dist\GMS-ULA-Setup-$version.exe"
if (-not (Test-Path $setup)) { throw "Нет файла $setup — сначала собери установщик" }

$notes = Join-Path $env:TEMP "gms-release-$version.md"
$changelog = Get-Content CHANGELOG.md -Raw -Encoding UTF8
if ($changelog -match "(?ms)^## $([regex]::Escape($version))\s*(.*?)(?=^## |\z)") {
  Set-Content -Path $notes -Value $Matches[1].Trim() -Encoding UTF8
} else {
  Set-Content -Path $notes -Value "GMS - ULA $version" -Encoding UTF8
}

$remote = (& git remote get-url origin 2>$null)
if (-not $remote) {
  & $gh repo create kolyaz/GMS --private --source=. --remote=origin --description "GMS - ULA"
}

& git add -f .gitignore README.md CHANGELOG.md VERSION scripts/publish-release.ps1
$status = & git status --porcelain
if ($status) {
  & git commit -m "Релиз $version."
}

$existing = & git rev-parse -q --verify "refs/tags/$tag" 2>$null
if ($existing) {
  & git tag -d $tag
}
& git tag $tag
& git push -u origin HEAD
& git push origin $tag

$release = & $gh release view $tag 2>$null
if ($LASTEXITCODE -eq 0) {
  & $gh release upload $tag $setup --clobber
} else {
  & $gh release create $tag $setup --title "GMS - ULA $version" --notes-file $notes --latest
}
Write-Host "OK $tag → https://github.com/kolyaz/GMS/releases/tag/$tag"
