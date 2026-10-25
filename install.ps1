# HaMoach Shelach - one-command setup for Windows.
# Run from cmd or PowerShell:
#   powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://hamoach.theofrina.com/install.ps1 | iex"
# What it does: installs Obsidian and the Claude desktop app (which includes Claude Code), creates the brain folder
# in the user's home folder, adds the brain skeleton and skills, moves the questionnaire answers in, registers the
# folder as an Obsidian vault, and opens everything. It never deletes or overwrites the user's own notes.
# Hebrew strings are built from code points so the script works whatever encoding it arrives in.
# Test without installing anything:  set HAMOACH_DRYRUN=1  (and optionally HAMOACH_ROOT=<a temp folder>)

& {
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

$Base = 'https://hamoach.theofrina.com'
if ($env:HAMOACH_BASE) { $Base = $env:HAMOACH_BASE }
$Dry = ($env:HAMOACH_DRYRUN -eq '1')
$UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0 Safari/537.36'

function Get-HebrewText([int[]]$codes) { -join ($codes | ForEach-Object { [char]$_ }) }
$VaultName = Get-HebrewText 0x05D4,0x05DE,0x05D5,0x05D7,0x20,0x05E9,0x05DC,0x05D9          # המוח שלי
$RawName   = '_' + (Get-HebrewText 0x05D2,0x05D5,0x05DC,0x05DE,0x05D9)                         # _גולמי
$MatName   = Get-HebrewText 0x05D7,0x05D5,0x05DE,0x05E8,0x05D9,0x05DD                         # חומרים
$QName     = Get-HebrewText 0x05E9,0x05D0,0x05DC,0x05D5,0x05DF                                 # שאלון
$BrainWord = Get-HebrewText 0x05D4,0x05DE,0x05D5,0x05D7                                        # המוח

$Root = $env:USERPROFILE
if ($env:HAMOACH_ROOT) { $Root = $env:HAMOACH_ROOT }
$Vault = Join-Path $Root $VaultName
$Tmp = Join-Path $env:TEMP ('hamoach-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Force -Path $Tmp | Out-Null

function Say($m)  { Write-Host ''; Write-Host ">> $m" -ForegroundColor Yellow }
function Ok($m)   { Write-Host "   OK  $m" -ForegroundColor Green }
function Warn($m) { Write-Host "   !!  $m" -ForegroundColor Magenta }
function Get-File($url, $out) { Invoke-WebRequest -Uri $url -OutFile $out -UseBasicParsing -Headers @{ 'User-Agent' = $UA } }
function Has-Winget { [bool](Get-Command winget -ErrorAction SilentlyContinue) }
function Find-Obsidian {
  foreach ($p in @((Join-Path $env:LOCALAPPDATA 'Programs\Obsidian\Obsidian.exe'), (Join-Path $env:ProgramFiles 'Obsidian\Obsidian.exe'))) { if (Test-Path $p) { return $p } }
  return $null
}
function Test-Claude {
  if (Test-Path (Join-Path $env:LOCALAPPDATA 'AnthropicClaude\claude.exe')) { return $true }
  try { if (Get-StartApps | Where-Object { $_.Name -eq 'Claude' }) { return $true } } catch {}
  return $false
}

Write-Host ''
Write-Host '  ================================' -ForegroundColor DarkYellow
Write-Host '     HaMoach Shelach  -  setup' -ForegroundColor Yellow
Write-Host '  ================================' -ForegroundColor DarkYellow
if ($Dry) { Warn 'DRY RUN: nothing will be installed or opened' }

try {
  # 1. Obsidian
  Say 'Step 1 of 7: Obsidian'
  if (Find-Obsidian) { Ok 'Obsidian is already installed' }
  elseif ($Dry) { Ok 'dry run: skipped' }
  else {
    if (Has-Winget) {
      winget install -e --id Obsidian.Obsidian --silent --accept-package-agreements --accept-source-agreements | Out-Host
    }
    if (-not (Find-Obsidian)) {
      Write-Host '   downloading Obsidian...'
      $rel = Invoke-RestMethod -Uri 'https://api.github.com/repos/obsidianmd/obsidian-releases/releases?per_page=10' -Headers @{ 'User-Agent' = $UA }
      $asset = $null
      foreach ($r in $rel) {
        $a = $r.assets | Where-Object { $_.name -match '^Obsidian-[\d\.]+\.exe$' } | Select-Object -First 1
        if ($a) { $asset = $a; break }
      }
      if (-not $asset) { throw 'Could not find the Obsidian installer' }
      $exe = Join-Path $Tmp $asset.name
      Get-File $asset.browser_download_url $exe
      Start-Process -FilePath $exe -ArgumentList '/S' -Wait
    }
    if (Find-Obsidian) { Ok 'Obsidian installed' } else { Warn 'Could not confirm Obsidian. You can download it from obsidian.md/download' }
  }

  # 2. Claude desktop (includes Claude Code)
  Say 'Step 2 of 7: Claude (desktop app with Claude Code)'
  if (Test-Claude) { Ok 'Claude is already installed' }
  elseif ($Dry) { Ok 'dry run: skipped' }
  else {
    if (Has-Winget) {
      winget install -e --id Anthropic.Claude --silent --accept-package-agreements --accept-source-agreements | Out-Host
    }
    if (-not (Test-Claude)) {
      Write-Host '   downloading Claude...'
      $arch = 'x64'
      if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { $arch = 'arm64' }
      $exe = Join-Path $Tmp 'ClaudeSetup.exe'
      Get-File "https://claude.ai/api/desktop/win32/$arch/setup/latest/redirect" $exe
      Start-Process -FilePath $exe -Wait
    }
    if (Test-Claude) { Ok 'Claude installed' } else { Warn 'Could not confirm Claude. You can download it from claude.com/download' }
  }

  # 3. The brain folder
  Say 'Step 3 of 7: your brain folder'
  New-Item -ItemType Directory -Force -Path $Vault | Out-Null
  $kitZip = Join-Path $Tmp 'kit.zip'
  Get-File "$Base/kit.zip" $kitZip
  $kitDir = Join-Path $Tmp 'kit'
  Expand-Archive -Path $kitZip -DestinationPath $kitDir -Force
  $added = 0
  Get-ChildItem -Path $kitDir -Recurse -File -Force | ForEach-Object {
    $rel = $_.FullName.Substring($kitDir.Length).TrimStart('\')
    $dest = Join-Path $Vault $rel
    if (-not (Test-Path $dest)) {
      New-Item -ItemType Directory -Force -Path (Split-Path $dest -Parent) | Out-Null
      Copy-Item -LiteralPath $_.FullName -Destination $dest
      $added++
    }
  }
  Ok "folder ready: $Vault ($added new files, nothing of yours was changed)"

  # 4. Skills for Obsidian formats (MIT, github.com/kepano/obsidian-skills)
  Say 'Step 4 of 7: skills'
  try {
    $skZip = Join-Path $Tmp 'obsidian-skills.zip'
    Get-File 'https://github.com/kepano/obsidian-skills/archive/refs/heads/main.zip' $skZip
    $skDir = Join-Path $Tmp 'obsidian-skills'
    Expand-Archive -Path $skZip -DestinationPath $skDir -Force
    $src = Get-ChildItem -Path $skDir -Directory | Select-Object -First 1
    $license = Join-Path $src.FullName 'LICENSE'
    foreach ($name in @('obsidian-markdown', 'json-canvas', 'obsidian-bases')) {
      $from = Join-Path $src.FullName ('skills\' + $name)
      if (Test-Path $from) {
        $to = Join-Path $Vault ('.claude\skills\' + $name)
        New-Item -ItemType Directory -Force -Path $to | Out-Null
        Copy-Item -Path (Join-Path $from '*') -Destination $to -Recurse -Force
        if (Test-Path $license) { Copy-Item -LiteralPath $license -Destination (Join-Path $to 'LICENSE') -Force }
      }
    }
    Ok 'build-brain, complete-brain, ingest, write-in-my-voice, obsidian-markdown, json-canvas, obsidian-bases'
  } catch { Warn 'Obsidian format skills were not added (the brain still works)' }

  # 5. Her personal brain (a zip we built and sent her). Re-running the line with a newer zip updates the brain.
  Say 'Step 5 of 7: your brain'
  $downloads = Join-Path $env:USERPROFILE 'Downloads'
  try { $p = (New-Object -ComObject Shell.Application).Namespace('shell:Downloads').Self.Path; if ($p) { $downloads = $p } } catch {}
  if ($env:HAMOACH_DOWNLOADS) { $downloads = $env:HAMOACH_DOWNLOADS }
  $bz = Get-ChildItem -Path $downloads -Filter "*$BrainWord*.zip" -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if ($bz) {
    $bDir = Join-Path $Tmp 'brain'
    Expand-Archive -LiteralPath $bz.FullName -DestinationPath $bDir -Force
    $bRoot = $bDir
    $top = @(Get-ChildItem -LiteralPath $bDir -Force)
    if ($top.Count -eq 1 -and $top[0].PSIsContainer) { $bRoot = $top[0].FullName }
    $n = 0
    Get-ChildItem -LiteralPath $bRoot -Recurse -File -Force | ForEach-Object {
      $rel = $_.FullName.Substring($bRoot.Length).TrimStart('\')
      $dest = Join-Path $Vault $rel
      New-Item -ItemType Directory -Force -Path (Split-Path $dest -Parent) | Out-Null
      Copy-Item -LiteralPath $_.FullName -Destination $dest -Force
      $n++
    }
    Ok "your brain is inside: $($bz.Name) ($n files)"
  } else {
    Warn 'No brain file in Downloads yet. When Ofri sends it, save it to Downloads and run this line again.'
  }

  # 6. The questionnaire answers, if she saved them
  Say 'Step 6 of 7: your questionnaire'
  $q = Get-ChildItem -Path $downloads -Filter "*$QName*.txt" -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  $rawDir = Join-Path $Vault $RawName
  New-Item -ItemType Directory -Force -Path $rawDir | Out-Null
  if ($q) {
    Copy-Item -LiteralPath $q.FullName -Destination (Join-Path $rawDir ($QName + '.txt')) -Force
    Ok "questionnaire copied: $($q.Name)"
  } else {
    Ok 'nothing to copy (you already sent it to Ofri)'
  }

  # 7. Open it as an Obsidian vault
  Say 'Step 7 of 7: connecting the folder to Obsidian'
  $cfg = Join-Path $env:APPDATA 'obsidian\obsidian.json'
  if ($Dry) { $cfg = Join-Path $Tmp 'obsidian.json' }
  $data = $null
  if (Test-Path $cfg) { try { $data = Get-Content -LiteralPath $cfg -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $data = $null } }
  if (-not $data) { $data = New-Object PSObject }
  if (-not ($data.PSObject.Properties.Name -contains 'vaults')) { $data | Add-Member -NotePropertyName vaults -NotePropertyValue (New-Object PSObject) }
  $id = $null
  foreach ($prop in @($data.vaults.PSObject.Properties)) {
    if ($prop.Value.path -eq $Vault) { $id = $prop.Name }
    elseif ($prop.Value.PSObject.Properties.Name -contains 'open') { $prop.Value.open = $false }
  }
  $entry = New-Object PSObject -Property @{ path = $Vault; ts = [long]([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()); open = $true }
  if ($id) { $data.vaults.$id = $entry }
  else { $id = -join ((1..16) | ForEach-Object { '{0:x}' -f (Get-Random -Maximum 16) }); $data.vaults | Add-Member -NotePropertyName $id -NotePropertyValue $entry }
  New-Item -ItemType Directory -Force -Path (Split-Path $cfg -Parent) | Out-Null
  [IO.File]::WriteAllText($cfg, ($data | ConvertTo-Json -Depth 6), (New-Object Text.UTF8Encoding $false))
  if (-not $Dry -and (Get-Process -Name Obsidian -ErrorAction SilentlyContinue)) { Warn 'Obsidian was already open. If your folder does not show, close Obsidian and open it again.' }
  Ok 'connected'

  if ($Dry) {
    Ok "dry run finished. Vault: $Vault  Config: $cfg"
  } else {
    $obs = Find-Obsidian
    if ($obs) { Start-Process -FilePath $obs }
    Start-Process -FilePath 'explorer.exe' -ArgumentList ('"' + (Join-Path $rawDir $MatName) + '"')
    Start-Process "$Base/start/"
  }

  Write-Host ''
  Write-Host '  ======================================================' -ForegroundColor DarkYellow
  Write-Host '   All set. Follow the page that just opened in your browser.' -ForegroundColor Green
  Write-Host '   Next: open Claude > Code > New session > choose your brain folder.
   Then follow the page: Claude will ask you what is still missing.' -ForegroundColor Green
  Write-Host '  ======================================================' -ForegroundColor DarkYellow
}
catch {
  Write-Host ''
  Write-Host "Something went wrong: $($_.Exception.Message)" -ForegroundColor Red
  Write-Host 'Take a screenshot of this window and send it to Ofri.' -ForegroundColor Red
}
finally {
  try { Remove-Item -LiteralPath $Tmp -Recurse -Force -ErrorAction SilentlyContinue } catch {}
}
}
