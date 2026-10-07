#requires -Version 5.1
<#
.SYNOPSIS
Audits the public source and builds the skills-only Guardhouse release ZIP.
.DESCRIPTION
Development tooling only. The release payload is an explicit allowlist, not a
copy of the checkout. Output must be outside the source repository. The default
is the sibling guardhouse-plugin-codex-release directory. No network requests,
external executables, dependencies, or personal configuration are required.
.PARAMETER OutputDirectory
An optional release directory outside the repository. Relative paths are
resolved against the current working directory. Existing archives are not
overwritten unless ReplaceArchive is supplied.
.PARAMETER ReplaceArchive
Replace only this manifest version's expected ZIP after all checks pass. The
verified ZIP is copied to a unique output-side file and atomically replaces the
existing archive; unrelated output files are never removed.
#>
[CmdletBinding()]
param(
    [string] $OutputDirectory,
    [switch] $ReplaceArchive
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:Phase = 'source audit'
$script:StageParent = $null
$script:StageRoot = $null
$script:CreatedStageParent = $false
$script:CreatedStageRoot = $false
$script:OutputTemporary = $null
$script:OutputTemporaryParent = $null
$script:CreatedOutputTemporary = $false

function Stop-Package {
    param([string] $Message, [string] $File)
    if ($File) { $Message = "$Message [$File]" }
    $errorRecord = New-Object System.InvalidOperationException($Message)
    $errorRecord.Data['GuardhousePackageError'] = $true
    throw $errorRecord
}

function Get-NormalPath {
    param([string] $Path)
    $fullPath = [System.IO.Path]::GetFullPath($Path)
    if ($fullPath -eq [System.IO.Path]::GetPathRoot($fullPath)) { return $fullPath }
    return $fullPath.TrimEnd([char[]] @('\', '/'))
}

function Test-WithinPath {
    param([string] $Path, [string] $Parent)
    $prefix = $Parent.TrimEnd([char[]] @('\', '/')) + [System.IO.Path]::DirectorySeparatorChar
    return $Path.Equals($Parent, [StringComparison]::OrdinalIgnoreCase) -or
        $Path.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)
}

function Assert-PlainAncestors {
    param([string] $Path)
    $cursor = $Path
    while ($cursor) {
        if (Test-Path -LiteralPath $cursor) {
            $entry = Get-Item -LiteralPath $cursor -Force
            if ($entry.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
                Stop-Package 'Reparse points are not allowed in source, staging, or output paths.'
            }
        }
        $parent = [System.IO.Path]::GetDirectoryName($cursor)
        if ($parent -eq $cursor) { break }
        $cursor = $parent
    }
}

function Get-SourceFiles {
    param([string] $Root)
    $files = New-Object 'System.Collections.Generic.Dictionary[string,System.IO.FileInfo]' ([StringComparer]::OrdinalIgnoreCase)
    $pending = New-Object 'System.Collections.Generic.Stack[string]'
    $pending.Push($Root)
    $artifactDirectories = @(
        '.validation', 'node_modules', '.venv', 'venv', '__pycache__', '.pytest_cache',
        '.mypy_cache', '.ruff_cache', '.tox', '.cache', 'cache', 'caches', '.npm',
        '.yarn', '.pnpm-store', '.nuget', 'packages', 'bin', 'obj', 'dist', 'build',
        'coverage', '.tmp', 'tmp', 'temp', '.codex', '.config', '.ssh', '.aws',
        '.idea', '.vscode'
    )
    while ($pending.Count) {
        $directory = $pending.Pop()
        foreach ($entry in Get-ChildItem -LiteralPath $directory -Force) {
            $relative = $entry.FullName.Substring($Root.Length + 1).Replace('\', '/')
            # A Git directory or worktree marker is private repository machinery.
            if ($relative -eq '.git') { continue }
            if ($entry.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
                Stop-Package 'Source reparse points are not allowed.' $relative
            }
            if ($entry.PSIsContainer) {
                if ($entry.Name -eq '.git' -or $artifactDirectories -contains $entry.Name) {
                    Stop-Package 'Remove local, dependency, or cache artifacts before packaging.' $relative
                }
                $pending.Push($entry.FullName)
            }
            else {
                if ($entry.Name -eq '.mcp.json' -or $entry.Name -eq 'auth.json' -or
                    $entry.Name -eq 'credentials.json' -or $entry.Name -eq 'config.toml' -or
                    $entry.Name -like '.env*' -or $entry.Name -eq '.DS_Store' -or
                    $entry.Name -eq 'Thumbs.db' -or
                    $entry.Extension -in @('.zip', '.log', '.tmp', '.pyc', '.pyo')) {
                    Stop-Package 'Local configuration or generated artifacts are not public source.' $relative
                }
                $files.Add($relative, $entry)
            }
        }
    }
    # Prevent PowerShell from unrolling the dictionary into key/value entries.
    return ,$files
}

function Test-PublicHost {
    param([uri] $Uri)
    $hostName = $Uri.DnsSafeHost.TrimEnd('.').ToLowerInvariant()
    $publicHosts = @(
        'guardhouse.cloud', 'github.com', 'developers.openai.com',
        'learn.chatgpt.com', 'www.apache.org', 'keepachangelog.com', 'semver.org'
    )
    if ($publicHosts -contains $hostName) { return $true }
    # Approve only the official Windows CLI installer documented for setup.
    if ($hostName -eq 'chatgpt.com') {
        return $Uri.Scheme -eq 'https' -and $Uri.IsDefaultPort -and
            $Uri.AbsolutePath -ceq '/codex/install.ps1' -and
            -not $Uri.Query -and -not $Uri.Fragment
    }
    if ($hostName -eq 'example' -or $hostName.EndsWith('.example') -or
        $hostName -eq 'invalid' -or $hostName.EndsWith('.invalid')) { return $true }
    foreach ($reserved in @('example.com', 'example.net', 'example.org')) {
        if ($hostName -eq $reserved -or $hostName.EndsWith('.' + $reserved)) { return $true }
    }
    if ($hostName -eq 'localhost' -or $hostName.EndsWith('.localhost')) { return $true }
    $address = $null
    if ([System.Net.IPAddress]::TryParse($hostName.Trim('[', ']'), [ref] $address)) {
        return [System.Net.IPAddress]::IsLoopback($address)
    }
    return $false
}

function Assert-PublicText {
    param([string] $Text, [string] $File)
    # Character classes keep the checks from matching their own source literals.
    $windowsPath = '(?i)(?<![a-z0-9])(?:[a-z]:[\\/]|\\\\[a-z0-9_.-]+[\\/][a-z0-9$_.-]+)'
    $unixHome = '(?i)(?<![a-z0-9])(?:[/]home[/][^/\s"''<>]+|[/]Users[/][^/\s"''<>]+|[/]root(?:[/]|\b))'
    if ([regex]::IsMatch($Text, $windowsPath) -or [regex]::IsMatch($Text, $unixHome)) {
        Stop-Package 'Privacy check found an absolute workstation or personal home path.' $File
    }
    # Only report the filename and failure category, never a matched URL or value.
    foreach ($match in [regex]::Matches($Text, '(?i)\bhttps?://[^\s<>"''`]+')) {
        $url = $match.Value.TrimEnd([char[]] @('.', ',', ';', ')', '}'))
        $uri = $null
        if (-not [uri]::TryCreate($url, [UriKind]::Absolute, [ref] $uri) -or
            -not $uri.Host -or $uri.UserInfo -or -not (Test-PublicHost $uri)) {
            Stop-Package 'Privacy check found an invalid or unapproved HTTP URL; review the public host allowlist intentionally.' $File
        }
    }
}

function Assert-PublicBytes {
    param([byte[]] $Bytes, [string] $File)
    Assert-PublicText ([System.Text.Encoding]::UTF8.GetString($Bytes)) $File
    # Scan both UTF-16 alignments too, including strings embedded in binary files.
    if ($Bytes.Length -gt 1) {
        foreach ($encoding in @([System.Text.Encoding]::Unicode, [System.Text.Encoding]::BigEndianUnicode)) {
            Assert-PublicText ($encoding.GetString($Bytes)) $File
            Assert-PublicText ($encoding.GetString($Bytes, 1, $Bytes.Length - 1)) $File
        }
    }
}

function Read-PublicUtf8 {
    param([string] $Path, [string] $File)
    try {
        $encoding = New-Object System.Text.UTF8Encoding($false, $true)
        return $encoding.GetString([System.IO.File]::ReadAllBytes($Path)).TrimStart([char] 0xFEFF)
    }
    catch { Stop-Package 'Public text must contain valid UTF-8.' $File }
}

function Assert-TextValue {
    param($Value, [string] $File, [string] $Field, [int] $Maximum = [int]::MaxValue,
        [switch] $Multiline, [switch] $AllowEmpty)
    if ($Value -isnot [string] -or $Value.Length -gt $Maximum -or
        (-not $AllowEmpty -and [string]::IsNullOrWhiteSpace($Value))) {
        Stop-Package ($Field + ' must be a non-empty string within its documented length limit.') $File
    }
    # Reject controls, separators and invisible formatting. Only long text may
    # contain ordinary CR/LF line breaks; tabs are never listing text.
    $unsupported = '[\p{Cc}\p{Cf}\p{Zl}\p{Zp}]'
    $check = $Value
    if ($Multiline) { $check = $check.Replace("`r", '').Replace("`n", '') }
    if ([regex]::IsMatch($check, $unsupported)) {
        Stop-Package ($Field + ' contains unsupported characters or line breaks.') $File
    }
    try { $null = $Value.Normalize([System.Text.NormalizationForm]::FormKC) }
    catch { Stop-Package ($Field + ' contains invalid Unicode text.') $File }
}

function Assert-ObjectFields {
    param($Value, [string[]] $Allowed, [string[]] $Required, [string] $File)
    if ($Value -isnot [System.Management.Automation.PSCustomObject]) {
        Stop-Package 'A required metadata object has the wrong type.' $File
    }
    foreach ($property in $Value.PSObject.Properties) {
        if ($Allowed -cnotcontains $property.Name) { Stop-Package 'Metadata contains an unsupported field.' $File }
    }
    foreach ($field in $Required) {
        if (-not $Value.PSObject.Properties[$field]) { Stop-Package 'A required metadata field is missing.' $File }
    }
}

function Assert-HttpsValue {
    param($Value, [string] $File, [int] $Maximum = 1024)
    Assert-TextValue $Value $File 'Metadata URL' $Maximum
    $uri = $null
    if (-not [uri]::TryCreate($Value, [UriKind]::Absolute, [ref] $uri) -or
        $uri.Scheme -ne 'https' -or -not $uri.Host -or $uri.UserInfo -or $Value -match '\s') {
        Stop-Package 'Metadata URLs must use HTTPS without whitespace or credentials.' $File
    }
}

function Get-ColorLuminance {
    param([string] $Color)
    $channels = @(0, 2, 4 | ForEach-Object {
        $channel = [Convert]::ToInt32($Color.Substring($_ + 1, 2), 16) / 255.0
        if ($channel -le 0.04045) { $channel / 12.92 }
        else { [math]::Pow(($channel + 0.055) / 1.055, 2.4) }
    })
    return 0.2126 * $channels[0] + 0.7152 * $channels[1] + 0.0722 * $channels[2]
}

function Assert-BrandColor {
    param($Value, [string] $File, [switch] $Dark)
    if ($Value -isnot [string] -or $Value -cnotmatch '^#[0-9A-Fa-f]{6}\z') {
        Stop-Package 'Brand colors must use six-digit hex notation.' $File
    }
    $luminance = Get-ColorLuminance $Value
    $background = 1.0
    if ($Dark) { $background = Get-ColorLuminance '#212121' }
    $contrast = ([math]::Max($luminance, $background) + 0.05) / ([math]::Min($luminance, $background) + 0.05)
    if ($contrast -lt 2.0) { Stop-Package 'Brand colors require at least 2:1 contrast against the documented background.' $File }
}

function Read-YamlString {
    param([string] $Raw, [string] $File)
    $rawValue = $Raw.Trim()
    if ($rawValue.StartsWith('"')) {
        if ($rawValue -notmatch '^("(?:[^"\\]|\\(?:["\\/bfnrt]|u[0-9a-fA-F]{4}))*")(?:\s+#.*)?\z') {
            Stop-Package 'Unsupported or malformed quoted YAML string.' $File
        }
        try { return ($Matches[1] | ConvertFrom-Json) }
        catch { Stop-Package 'Malformed quoted YAML string.' $File }
    }
    if ($rawValue.StartsWith("'")) {
        if ($rawValue -notmatch "^'((?:[^']|'')*)'(?:\s+#.*)?\z") {
            Stop-Package 'Malformed single-quoted YAML string.' $File
        }
        return $Matches[1].Replace("''", "'")
    }
    $rawValue = [regex]::Replace($rawValue, '\s+#.*\z', '')
    if (-not $rawValue -or $rawValue -match '^[\[\]{}&*!|>?#%@`]|:\s|\s[\[\]{}]|^(?:true|false|null|~|[-+]?\d+(?:\.\d+)?)\z') {
        Stop-Package 'Use a quoted string or a simple plain string in authored YAML.' $File
    }
    return $rawValue
}

function Assert-SkillMetadata {
    param([string] $SkillFile, [string] $Root, $Payload)
    # Deliberately constrained authored YAML: name/description single-line
    # string scalars in front matter; interface/policy mappings in agent files;
    # two-space property indentation and inline or block product string lists.
    # Duplicate keys, anchors, tags, merge keys, complex values and multiline
    # scalars are rejected. This is not a general-purpose YAML parser.
    $text = Read-PublicUtf8 $Payload[$SkillFile].FullName $SkillFile
    $lines = $text -split '\r?\n'
    if ($lines[0] -cne '---') { Stop-Package 'Skill front matter must start with a YAML delimiter.' $SkillFile }
    $frontMatter = @{}
    $closed = $false
    for ($i = 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -ceq '---') { $closed = $true; break }
        if ($lines[$i] -match '^\s*(?:#.*)?$') { continue }
        if ($lines[$i] -cnotmatch '^(name|description):\s*(.+)\z' -or $frontMatter.ContainsKey($Matches[1])) {
            Stop-Package 'Skill front matter contains malformed, duplicate, or unsupported fields.' $SkillFile
        }
        $key = $Matches[1]
        $frontMatter[$key] = Read-YamlString $Matches[2] $SkillFile
    }
    if (-not $closed -or -not $frontMatter.ContainsKey('name') -or -not $frontMatter.ContainsKey('description')) {
        Stop-Package 'Skill front matter requires a closed mapping with name and description.' $SkillFile
    }
    $skillName = $frontMatter['name']
    Assert-TextValue $skillName $SkillFile 'Skill name' 64
    Assert-TextValue $frontMatter['description'] $SkillFile 'Skill description' 1024
    $directoryName = ($SkillFile -split '/')[1]
    if ($skillName -cne $directoryName -or $skillName -cnotmatch '^[a-z0-9]+(?:-[a-z0-9]+)*\z' -or
        ('guardhouse:' + $skillName).Length -gt 64) {
        Stop-Package 'Skill identity must match its directory and fit the combined-name limit.' $SkillFile
    }

    $agentFile = 'skills/' + $skillName + '/agents/openai.yaml'
    $agentText = Read-PublicUtf8 $Payload[$agentFile].FullName $agentFile
    $agent = @{}
    $section = $null
    $blockProducts = $false
    foreach ($line in ($agentText -split '\r?\n')) {
        if ($line -match '^\s*(?:#.*)?$') { continue }
        if ($line -cmatch '^(interface|policy):\s*(?:#.*)?$') {
            $section = $Matches[1]
            if ($agent.ContainsKey($section)) { Stop-Package 'Agent YAML contains a duplicate mapping.' $agentFile }
            $agent[$section] = @{}
            $blockProducts = $false
        }
        elseif ($line -cmatch '^  ([a-z_]+):\s*(.*)\z' -and $section) {
            $key = $Matches[1]; $raw = $Matches[2]
            $blockProducts = $false
            if ($agent[$section].ContainsKey($key)) { Stop-Package 'Agent YAML contains a duplicate field.' $agentFile }
            if ($section -eq 'interface') {
                if (@('display_name', 'short_description', 'default_prompt', 'brand_color', 'icon_small', 'icon_large') -cnotcontains $key) {
                    Stop-Package 'Agent interface contains an unsupported field.' $agentFile
                }
                $agent[$section][$key] = Read-YamlString $raw $agentFile
                Assert-TextValue $agent[$section][$key] $agentFile 'Agent interface text'
            }
            elseif ($key -eq 'products') {
                $products = New-Object 'System.Collections.Generic.List[string]'
                if ($raw -match '^\s*(?:#.*)?$') { $blockProducts = $true }
                elseif ($raw -match '^\[([^\]]*)\]\s*(?:#.*)?\z') {
                    foreach ($product in ($Matches[1] -split ',')) { $products.Add((Read-YamlString $product $agentFile)) }
                }
                else { Stop-Package 'Agent policy products must be a string list.' $agentFile }
                $agent[$section][$key] = $products
            }
            elseif ($key -eq 'allow_implicit_invocation' -and $raw -cmatch '^(true|false)\s*(?:#.*)?\z') {
                $agent[$section][$key] = $Matches[1] -ceq 'true'
            }
            else { Stop-Package 'Agent policy contains an unsupported or wrongly typed field.' $agentFile }
        }
        elseif ($blockProducts -and $line -cmatch '^    -\s+(.+)\z') {
            $agent['policy']['products'].Add((Read-YamlString $Matches[1] $agentFile))
        }
        else { Stop-Package 'Agent YAML is malformed or outside the documented authored subset.' $agentFile }
    }
    if (-not $agent.ContainsKey('interface') -or -not $agent['interface'].ContainsKey('display_name') -or
        -not $agent['interface'].ContainsKey('short_description')) {
        Stop-Package 'Agent interface requires display_name and short_description.' $agentFile
    }
    if (-not $agent.ContainsKey('policy') -or -not $agent['policy'].ContainsKey('products') -or
        $agent['policy']['products'].Count -ne 1 -or $agent['policy']['products'][0] -cne 'CODEX') {
        Stop-Package 'This local plugin requires agent policy products to contain only CODEX.' $agentFile
    }
    if ($agent['interface'].ContainsKey('default_prompt') -and
        $agent['interface']['default_prompt'] -notmatch ('\$' + [regex]::Escape($skillName) + '(?![a-z0-9-])')) {
        Stop-Package 'The agent starter prompt must reference its own skill name.' $agentFile
    }
    if ($agent['interface'].ContainsKey('brand_color')) { Assert-BrandColor $agent['interface']['brand_color'] $agentFile }
    foreach ($iconProperty in @('icon_small', 'icon_large')) {
        if ($agent['interface'].ContainsKey($iconProperty)) {
            $icon = Resolve-PayloadResource $agent['interface'][$iconProperty] $agentFile $Root $Payload
            if ($Payload[$icon].Extension -ne '.png') { Stop-Package 'Authored agent icons must use PNG resources.' $agentFile }
            Assert-Png $Payload[$icon].FullName $icon
        }
    }
}

function Resolve-PayloadResource {
    param([string] $Value, [string] $FromFile, [string] $Root, $Payload, [switch] $Directory)
    if ([string]::IsNullOrWhiteSpace($Value)) { Stop-Package 'A required local resource is missing.' $FromFile }
    if ($Value -match '^[a-z][a-z0-9+.-]*:' -or $Value.StartsWith('/') -or $Value.StartsWith('\')) {
        Stop-Package 'Package resources must use relative local paths.' $FromFile
    }
    $pathPart = ($Value -split '[#?]', 2)[0]
    if (-not $pathPart) { return }
    $pathPart = [uri]::UnescapeDataString($pathPart)
    if ([System.IO.Path]::IsPathRooted($pathPart)) {
        Stop-Package 'Package resources must use relative local paths.' $FromFile
    }
    $sourcePath = Join-Path $Root $FromFile.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
    $target = Get-NormalPath (Join-Path ([System.IO.Path]::GetDirectoryName($sourcePath)) $pathPart)
    if (-not (Test-WithinPath $target $Root) -or $target -eq $Root) {
        Stop-Package 'A local resource escapes the release payload.' $FromFile
    }
    $relative = $target.Substring($Root.Length + 1).Replace('\', '/')
    if ($Directory) {
        $prefix = $relative.TrimEnd('/') + '/'
        if (-not @($Payload.Keys | Where-Object { $_.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) }).Count) {
            Stop-Package 'A local resource directory is absent from the release payload.' $FromFile
        }
    }
    elseif (-not $Payload.ContainsKey($relative)) {
        Stop-Package 'A local resource is absent from the release payload.' $FromFile
    }
    return $relative
}

function Assert-MarkdownResources {
    param([string] $Text, [string] $File, [string] $Root, $Payload)
    $destinations = New-Object 'System.Collections.Generic.List[string]'
    # Inline links/images and reference definitions used by this package.
    foreach ($match in [regex]::Matches($Text, '\]\(\s*(?:<(?<path>[^>]+)>|(?<path>[^\s)]+))(?:\s+["''][^\r\n]*["''])?\s*\)')) {
        $destinations.Add($match.Groups['path'].Value)
    }
    foreach ($match in [regex]::Matches($Text, '(?m)^\s{0,3}\[[^\]\r\n]+\]:\s*(?:<(?<path>[^>]+)>|(?<path>\S+))')) {
        $destinations.Add($match.Groups['path'].Value)
    }
    # Skill instructions also cite local resources in code spans.
    foreach ($match in [regex]::Matches($Text, '`(?<path>(?:\./|\.\./)*(?:references|agents|assets)/[^`\r\n]+)`')) {
        $destinations.Add($match.Groups['path'].Value)
    }
    foreach ($destination in $destinations) {
        if ($destination.StartsWith('#') -or $destination -match '^[a-z][a-z0-9+.-]*:') { continue }
        $null = Resolve-PayloadResource $destination $File $Root $Payload
    }
}

function Assert-Png {
    param([string] $Path, [string] $File)
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -lt 33 -or $bytes.Length -gt 5MB -or
        [BitConverter]::ToString($bytes, 0, 8) -ne '89-50-4E-47-0D-0A-1A-0A') {
        Stop-Package 'Required icons must be PNG files of at most 5 MiB.' $File
    }
    # Text/EXIF chunks can carry hidden workstation or private deployment data.
    $offset = 8
    $hasEnd = $false
    while ($offset -lt $bytes.Length) {
        if ($offset + 12 -gt $bytes.Length) { Stop-Package 'Malformed PNG chunk structure.' $File }
        $length = ([long] $bytes[$offset] * 16777216) + ([long] $bytes[$offset + 1] * 65536) +
            ([long] $bytes[$offset + 2] * 256) + $bytes[$offset + 3]
        if ($offset + 12 + $length -gt $bytes.Length) { Stop-Package 'Malformed PNG chunk structure.' $File }
        $kind = [System.Text.Encoding]::ASCII.GetString($bytes, $offset + 4, 4)
        if ($kind -in @('tEXt', 'zTXt', 'iTXt', 'eXIf')) {
            Stop-Package 'Release icons must not contain text or EXIF metadata.' $File
        }
        $offset += 12 + $length
        if ($kind -eq 'IEND') { $hasEnd = $true; break }
    }
    if (-not $hasEnd -or $offset -ne $bytes.Length) { Stop-Package 'Malformed PNG ending or trailing data.' $File }
    $stream = New-Object System.IO.MemoryStream(,$bytes)
    $image = $null
    try {
        $image = [System.Drawing.Image]::FromStream($stream, $false, $true)
        if ($image.RawFormat.Guid -ne [System.Drawing.Imaging.ImageFormat]::Png.Guid -or
            $image.Width -ne $image.Height -or $image.Width -lt 48 -or $image.Width -gt 4096) {
            Stop-Package 'Required PNG icons must be square and 48 through 4096 pixels.' $File
        }
    }
    finally {
        if ($image) { $image.Dispose() }
        $stream.Dispose()
    }
}

function Get-Sha256 {
    param([byte[]] $Bytes)
    $algorithm = [System.Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($algorithm.ComputeHash($Bytes)) }
    finally { $algorithm.Dispose() }
}

function Remove-PrivateStage {
    # Recursively remove only the exact child created by this invocation. Check
    # the captured parent, normalized location, and every entry before deletion.
    if ($script:CreatedStageRoot) {
        $actual = Get-NormalPath $script:StageRoot
        $expected = Get-NormalPath (Join-Path $script:StageParent 'work')
        if ($actual -ne $expected -or [System.IO.Path]::GetDirectoryName($actual) -ne $script:StageParent) {
            Stop-Package 'Temporary cleanup refused an unexpected target.'
        }
        Assert-PlainAncestors $actual
        $pending = New-Object 'System.Collections.Generic.Stack[string]'
        $pending.Push($actual)
        while ($pending.Count) {
            foreach ($entry in Get-ChildItem -LiteralPath $pending.Pop() -Force) {
                if ($entry.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
                    Stop-Package 'Temporary cleanup refused a reparse point.'
                }
                if ($entry.PSIsContainer) { $pending.Push($entry.FullName) }
            }
        }
        Remove-Item -LiteralPath $actual -Recurse -Force
        $script:CreatedStageRoot = $false
    }
    if ($script:CreatedStageParent) {
        Assert-PlainAncestors $script:StageParent
        # Nonrecursive removal fails safely if anything unexpected was added.
        [System.IO.Directory]::Delete($script:StageParent, $false)
        $script:CreatedStageParent = $false
    }
}

function Remove-OutputTemporary {
    if (-not $script:CreatedOutputTemporary) { return }
    $target = Get-NormalPath $script:OutputTemporary
    if ([System.IO.Path]::GetDirectoryName($target) -ne $script:OutputTemporaryParent -or
        [System.IO.Path]::GetFileName($target) -notmatch '^\.guardhouse-.+\.zip\.[a-f0-9]{32}\.tmp\z') {
        Stop-Package 'Output cleanup refused an unexpected file target.'
    }
    Assert-PlainAncestors $target
    [System.IO.File]::Delete($target)
    $script:CreatedOutputTemporary = $false
}

$failure = $null
try {
    $sourceRoot = Get-NormalPath (Join-Path $PSScriptRoot '..')
    Assert-PlainAncestors $sourceRoot
    if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
        $OutputDirectory = Join-Path ([System.IO.Path]::GetDirectoryName($sourceRoot)) 'guardhouse-plugin-codex-release'
    }
    $outputRoot = Get-NormalPath $OutputDirectory
    Assert-PlainAncestors $outputRoot
    if ((Test-WithinPath $outputRoot $sourceRoot) -or (Test-WithinPath $sourceRoot $outputRoot)) {
        Stop-Package 'Choose an output directory outside the repository and distinct from its ancestors.'
    }
    $sourceFiles = Get-SourceFiles $sourceRoot
    $sourceDigests = New-Object 'System.Collections.Generic.Dictionary[string,string]' ([StringComparer]::OrdinalIgnoreCase)
    $executableExtensions = @('.exe', '.dll', '.com', '.msi', '.bat', '.cmd', '.ps1', '.psm1', '.psd1', '.sh', '.py', '.js', '.mjs', '.cjs', '.ts', '.wasm')
    foreach ($relative in @($sourceFiles.Keys | Sort-Object)) {
        $file = $sourceFiles[$relative]
        if ($executableExtensions -contains $file.Extension -and $relative -ne 'scripts/build-package.ps1') {
            Stop-Package 'Unexpected executable source is not allowed in this declarative plugin.' $relative
        }
        $sourceBytes = [System.IO.File]::ReadAllBytes($file.FullName)
        Assert-PublicBytes $sourceBytes $relative
        $sourceDigests.Add($relative, (Get-Sha256 $sourceBytes))
    }

    $script:Phase = 'payload validation'
    $payload = New-Object 'System.Collections.Generic.Dictionary[string,System.IO.FileInfo]' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($relative in @('.codex-plugin/plugin.json', 'assets/icon.png', 'LICENSE', 'README.md', 'SECURITY.md')) {
        if (-not $sourceFiles.ContainsKey($relative)) { Stop-Package 'Required release file is missing.' $relative }
        $payload.Add($relative, $sourceFiles[$relative])
    }
    $skillExtensions = @('.md', '.txt', '.json', '.yaml', '.yml', '.toml', '.png', '.jpg', '.jpeg', '.gif', '.webp', '.svg')
    foreach ($relative in @($sourceFiles.Keys | Sort-Object)) {
        if ($relative.StartsWith('skills/', [StringComparison]::OrdinalIgnoreCase)) {
            if ($skillExtensions -notcontains $sourceFiles[$relative].Extension) {
                Stop-Package 'Skill resources must be declarative documents or images.' $relative
            }
            $payload.Add($relative, $sourceFiles[$relative])
        }
    }
    $skillNames = @($payload.Keys | Where-Object { $_ -match '^skills/[^/]+/SKILL\.md$' })
    if (-not $skillNames.Count) { Stop-Package 'At least one skill entry is required.' }
    foreach ($requiredSkill in @('guardhouse', 'guardhouse-applications', 'guardhouse-branding')) {
        if (-not $payload.ContainsKey('skills/' + $requiredSkill + '/SKILL.md')) {
            Stop-Package 'A required Guardhouse skill is missing.'
        }
    }
    foreach ($skill in $skillNames) {
        $agent = $skill.Substring(0, $skill.LastIndexOf('/') + 1) + 'agents/openai.yaml'
        if (-not $payload.ContainsKey($agent)) { Stop-Package 'Required skill agent metadata is missing.' $skill }
    }
    foreach ($relative in $payload.Keys) {
        if ($relative -match '^skills/([^/]+)/' -and -not $payload.ContainsKey('skills/' + $Matches[1] + '/SKILL.md')) {
            Stop-Package 'A skill resource has no corresponding SKILL.md.' $relative
        }
    }

    $manifestFile = '.codex-plugin/plugin.json'
    try { $manifest = (Read-PublicUtf8 $payload[$manifestFile].FullName $manifestFile) | ConvertFrom-Json }
    catch { Stop-Package 'The public manifest is not valid JSON.' $manifestFile }
    $manifestFields = @('id', 'name', 'version', 'description', 'author', 'homepage', 'repository', 'license', 'keywords', 'skills', 'interface', 'extensions')
    Assert-ObjectFields $manifest $manifestFields @('name', 'version', 'description', 'author', 'skills', 'interface') $manifestFile
    Assert-TextValue $manifest.name $manifestFile 'Package name' 64
    Assert-TextValue $manifest.version $manifestFile 'Package version' 64
    Assert-TextValue $manifest.description $manifestFile 'Package description' 1024 -Multiline
    Assert-ObjectFields $manifest.author @('name', 'email', 'url') @('name') $manifestFile
    Assert-TextValue $manifest.author.name $manifestFile 'Publisher name' 120
    if ($manifest.author.PSObject.Properties['email']) { Assert-TextValue $manifest.author.email $manifestFile 'Publisher email' 320 }
    if ($manifest.author.PSObject.Properties['url']) { Assert-HttpsValue $manifest.author.url $manifestFile 2048 }
    foreach ($urlProperty in @('homepage', 'repository')) {
        if ($manifest.PSObject.Properties[$urlProperty]) { Assert-HttpsValue $manifest.$urlProperty $manifestFile 2048 }
    }
    foreach ($textProperty in @('id', 'license')) {
        if ($manifest.PSObject.Properties[$textProperty]) { Assert-TextValue $manifest.$textProperty $manifestFile 'Package text' }
    }
    if ($manifest.PSObject.Properties['keywords']) {
        if ($manifest.keywords -isnot [array]) { Stop-Package 'Package keywords must be a string array.' $manifestFile }
        foreach ($keyword in $manifest.keywords) { Assert-TextValue $keyword $manifestFile 'Package keyword' }
    }
    $semver = '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?\z'
    if ($manifest.name -cne 'guardhouse' -or $manifest.version -isnot [string] -or
        $manifest.version.Length -gt 64 -or $manifest.version -notmatch $semver) {
        Stop-Package 'The public manifest must use guardhouse and a valid semantic version.' $manifestFile
    }
    $interfaceFields = @('displayName', 'shortDescription', 'longDescription', 'developerName', 'category', 'capabilities',
        'websiteURL', 'supportURL', 'privacyPolicyURL', 'termsOfServiceURL', 'defaultPrompt', 'brandColor', 'brandColorDark',
        'composerIcon', 'composerIconDark', 'logo', 'logoDark', 'screenshots')
    Assert-ObjectFields $manifest.interface $interfaceFields @('displayName', 'shortDescription', 'longDescription',
        'developerName', 'category', 'capabilities', 'defaultPrompt', 'composerIcon', 'logo') $manifestFile
    Assert-TextValue $manifest.interface.displayName $manifestFile 'Listing display name' 30
    Assert-TextValue $manifest.interface.shortDescription $manifestFile 'Listing short description' 30
    Assert-TextValue $manifest.interface.longDescription $manifestFile 'Listing long description' 4000 -Multiline
    Assert-TextValue $manifest.interface.developerName $manifestFile 'Listing developer name' 80
    Assert-TextValue $manifest.interface.category $manifestFile 'Listing category'
    $categories = @('Productivity', 'Creativity', 'Developer Tools', 'Business & Operations', 'Data & Analytics',
        'Communication', 'Education & Research', 'Security', 'Finance', 'Healthcare', 'Travel', 'Entertainment', 'Other')
    if ($categories -cnotcontains $manifest.interface.category) { Stop-Package 'The listing category is not supported.' $manifestFile }
    if ($manifest.interface.capabilities -isnot [array] -or $manifest.interface.capabilities.Count -gt 20) {
        Stop-Package 'Listing capabilities must be a string array of at most 20 entries.' $manifestFile
    }
    foreach ($capability in $manifest.interface.capabilities) { Assert-TextValue $capability $manifestFile 'Listing capability' 120 }
    foreach ($urlProperty in @('websiteURL', 'supportURL', 'privacyPolicyURL', 'termsOfServiceURL')) {
        if ($manifest.interface.PSObject.Properties[$urlProperty]) { Assert-HttpsValue $manifest.interface.$urlProperty $manifestFile }
    }
    if ($manifest.interface.PSObject.Properties['defaultPrompt']) {
        $prompts = $manifest.interface.defaultPrompt
        if ($prompts -is [string]) { $prompts = @($prompts) }
        if ($prompts -isnot [array] -or $prompts.Count -lt 1 -or $prompts.Count -gt 3) {
            Stop-Package 'Listing starter prompts must contain 1 through 3 strings when supplied.' $manifestFile
        }
        $uniquePrompts = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
        foreach ($prompt in $prompts) {
            Assert-TextValue $prompt $manifestFile 'Listing starter prompt' 128
            $normalized = [regex]::Replace($prompt.Normalize([System.Text.NormalizationForm]::FormKC), '\s+', ' ').Trim()
            if (-not $uniquePrompts.Add($normalized)) { Stop-Package 'Listing starter prompts must be unique after normalization.' $manifestFile }
            if ($prompt -match '@[\p{L}\p{N}_-]+') { Stop-Package 'Listing starter prompts must not contain app or MCP mentions.' $manifestFile }
        }
    }
    foreach ($colorProperty in @('brandColor', 'brandColorDark')) {
        if ($manifest.interface.PSObject.Properties[$colorProperty]) {
            Assert-BrandColor $manifest.interface.$colorProperty $manifestFile -Dark:($colorProperty -eq 'brandColorDark')
        }
    }
    if ($manifest.PSObject.Properties['extensions']) {
        Assert-ObjectFields $manifest.extensions @('com.openai') @() $manifestFile
        if ($manifest.extensions.PSObject.Properties['com.openai']) {
            $openai = $manifest.extensions.'com.openai'
            # Skills-only optional fields. MCP review metadata and credentials
            # do not belong in this package; other publication fields require
            # intentionally extending this validator alongside their schema.
            Assert-ObjectFields $openai @('onboardingSkill', 'publication') @() $manifestFile
            if ($openai.PSObject.Properties['onboardingSkill']) {
                Assert-TextValue $openai.onboardingSkill $manifestFile 'Onboarding skill path'
                $onboarding = Resolve-PayloadResource $openai.onboardingSkill 'README.md' $sourceRoot $payload
                if ($skillNames -cnotcontains $onboarding) { Stop-Package 'Onboarding must reference an included skill entry.' $manifestFile }
            }
            if ($openai.PSObject.Properties['publication']) {
                Assert-ObjectFields $openai.publication @('release_notes') @() $manifestFile
                if ($openai.publication.PSObject.Properties['release_notes'] -and $null -ne $openai.publication.release_notes) {
                    Assert-TextValue $openai.publication.release_notes $manifestFile 'Publication release notes' -Multiline -AllowEmpty
                }
            }
        }
    }
    Assert-TextValue $manifest.skills $manifestFile 'Skills resource path'
    $null = Resolve-PayloadResource $manifest.skills 'README.md' $sourceRoot $payload -Directory
    Add-Type -AssemblyName System.Drawing
    foreach ($iconProperty in @('composerIcon', 'logo', 'composerIconDark', 'logoDark')) {
        if (-not $manifest.interface.PSObject.Properties[$iconProperty]) { continue }
        Assert-TextValue $manifest.interface.$iconProperty $manifestFile 'Icon resource path'
        $icon = Resolve-PayloadResource $manifest.interface.$iconProperty 'README.md' $sourceRoot $payload
        if ($icon -ne 'assets/icon.png') { Stop-Package 'Required manifest icons must use the allowlisted PNG.' $manifestFile }
        Assert-Png $payload[$icon].FullName $icon
    }
    if ($manifest.interface.PSObject.Properties['screenshots']) {
        if ($manifest.interface.screenshots -isnot [array]) { Stop-Package 'Screenshots must be an array of local resource paths.' $manifestFile }
        foreach ($screenshot in $manifest.interface.screenshots) {
            Assert-TextValue $screenshot $manifestFile 'Screenshot path'
            $resource = Resolve-PayloadResource $screenshot 'README.md' $sourceRoot $payload
            if ($payload[$resource].Extension -notin @('.png', '.jpg', '.jpeg', '.webp', '.svg') -or $payload[$resource].Length -gt 5MB) {
                Stop-Package 'Screenshots must reference supported images of at most 5 MiB.' $manifestFile
            }
        }
    }
    foreach ($skill in $skillNames) { Assert-SkillMetadata $skill $sourceRoot $payload }
    foreach ($relative in $payload.Keys) {
        if ($payload[$relative].Extension -eq '.md') {
            Assert-MarkdownResources (Read-PublicUtf8 $payload[$relative].FullName $relative) $relative $sourceRoot $payload
        }
    }

    $archiveName = 'guardhouse-' + $manifest.version + '.zip'
    $destination = Join-Path $outputRoot $archiveName
    if ((Test-Path -LiteralPath $destination) -and -not $ReplaceArchive) {
        Stop-Package 'The archive already exists; choose another output directory or explicitly use ReplaceArchive.' $archiveName
    }
    Assert-PlainAncestors $destination
    if ((Test-Path -LiteralPath $destination) -and -not (Test-Path -LiteralPath $destination -PathType Leaf)) {
        Stop-Package 'The expected archive destination is not a regular file.' $archiveName
    }
    $script:Phase = 'private staging'
    $script:StageParent = Get-NormalPath (Join-Path ([System.IO.Path]::GetTempPath()) ('guardhouse-package-' + [Guid]::NewGuid().ToString('N')))
    if (Test-Path -LiteralPath $script:StageParent) { Stop-Package 'The private staging directory already exists.' }
    Assert-PlainAncestors $script:StageParent
    $null = [System.IO.Directory]::CreateDirectory($script:StageParent)
    $script:CreatedStageParent = $true
    $script:StageRoot = Get-NormalPath (Join-Path $script:StageParent 'work')
    $null = [System.IO.Directory]::CreateDirectory($script:StageRoot)
    $script:CreatedStageRoot = $true
    $packageRoot = Join-Path $script:StageRoot 'payload'
    $null = [System.IO.Directory]::CreateDirectory($packageRoot)
    $digests = New-Object 'System.Collections.Generic.Dictionary[string,string]' ([StringComparer]::Ordinal)
    foreach ($relative in @($payload.Keys | Sort-Object)) {
        # Re-audit the exact bytes that will be packaged in case a source file
        # changed after the initial scan. Never follow a replacement symlink.
        $sourceFile = Get-Item -LiteralPath $payload[$relative].FullName -Force
        if ($sourceFile.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            Stop-Package 'A source resource changed to a reparse point.' $relative
        }
        $bytes = [System.IO.File]::ReadAllBytes($sourceFile.FullName)
        Assert-PublicBytes $bytes $relative
        if ((Get-Sha256 $bytes) -ne $sourceDigests[$relative]) { Stop-Package 'A release source file changed during validation; rerun the build.' $relative }
        $target = Join-Path $packageRoot $relative.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
        $null = [System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($target))
        [System.IO.File]::WriteAllBytes($target, $bytes)
        $digests.Add($relative, (Get-Sha256 $bytes))
    }

    $script:Phase = 'archive verification'
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $stagedArchive = Join-Path $script:StageRoot $archiveName
    $zip = [System.IO.Compression.ZipFile]::Open($stagedArchive, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($relative in @($payload.Keys | Sort-Object)) {
            $stagedFile = Join-Path $packageRoot $relative.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
            $null = [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $stagedFile, $relative, [System.IO.Compression.CompressionLevel]::Optimal)
        }
    }
    finally { $zip.Dispose() }
    $zip = [System.IO.Compression.ZipFile]::OpenRead($stagedArchive)
    try {
        $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
        foreach ($entry in $zip.Entries) {
            $relative = $entry.FullName
            if ($relative.Contains('\') -or $relative.StartsWith('/') -or $relative -match '(^|/)\.\.(/|$)' -or
                $relative -match '(^|/)(?:\.mcp\.json|mcp|apps?|hooks)(?:/|$)' -or
                -not $digests.ContainsKey($relative) -or -not $seen.Add($relative)) {
                Stop-Package 'The archive contains an unexpected or unsafe entry.'
            }
            $entryStream = $entry.Open()
            $buffer = New-Object System.IO.MemoryStream
            try { $entryStream.CopyTo($buffer); $bytes = $buffer.ToArray() }
            finally { $buffer.Dispose(); $entryStream.Dispose() }
            if ((Get-Sha256 $bytes) -ne $digests[$relative]) { Stop-Package 'Archive content verification failed.' $relative }
            Assert-PublicBytes $bytes $relative
        }
        if ($seen.Count -ne $payload.Count) { Stop-Package 'The archive is missing an allowlisted resource.' }
    }
    finally { $zip.Dispose() }

    $script:Phase = 'release output'
    Assert-PlainAncestors $outputRoot
    $null = [System.IO.Directory]::CreateDirectory($outputRoot)
    Assert-PlainAncestors $outputRoot
    $normalizedDestination = Get-NormalPath $destination
    if ([System.IO.Path]::GetDirectoryName($normalizedDestination) -ne $outputRoot -or
        [System.IO.Path]::GetFileName($normalizedDestination) -cne $archiveName -or
        (Test-WithinPath $normalizedDestination $sourceRoot)) {
        Stop-Package 'Release output refused an unexpected archive target.'
    }
    Assert-PlainAncestors $normalizedDestination
    # Reserve a unique output-side file with CreateNew. Replacement is atomic
    # on the output volume and happens only after verifying these copied bytes.
    $script:OutputTemporaryParent = $outputRoot
    $script:OutputTemporary = Join-Path $outputRoot ('.' + $archiveName + '.' + [Guid]::NewGuid().ToString('N') + '.tmp')
    $outputStream = [System.IO.File]::Open($script:OutputTemporary, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write)
    $script:CreatedOutputTemporary = $true
    $inputStream = $null
    try {
        $inputStream = [System.IO.File]::OpenRead($stagedArchive)
        $inputStream.CopyTo($outputStream)
    }
    finally {
        if ($inputStream) { $inputStream.Dispose() }
        $outputStream.Dispose()
    }
    if ((Get-Sha256 ([System.IO.File]::ReadAllBytes($script:OutputTemporary))) -ne
        (Get-Sha256 ([System.IO.File]::ReadAllBytes($stagedArchive)))) {
        Stop-Package 'Output-side archive verification failed.' $archiveName
    }
    Assert-PlainAncestors $normalizedDestination
    if (Test-Path -LiteralPath $normalizedDestination) {
        if (-not $ReplaceArchive -or -not (Test-Path -LiteralPath $normalizedDestination -PathType Leaf)) {
            Stop-Package 'The expected archive changed during the build; replacement was refused.' $archiveName
        }
        # Windows PowerShell converts $null string arguments to empty strings;
        # NullString passes the actual null required for an absent backup path.
        [System.IO.File]::Replace($script:OutputTemporary, $normalizedDestination, [System.Management.Automation.Language.NullString]::Value)
    }
    else { [System.IO.File]::Move($script:OutputTemporary, $normalizedDestination) }
    $script:CreatedOutputTemporary = $false
    Write-Host ('Created {0} ({1} allowlisted files). Source privacy and ZIP verification passed.' -f $archiveName, $payload.Count)
    Write-Host ('Archive: ' + $destination)
}
catch {
    if ($_.Exception.Data['GuardhousePackageError']) { $failure = $_.Exception.Message }
    else { $failure = 'Package build failed during ' + $script:Phase + '; no file contents or private paths were logged.' }
}
finally {
    try { Remove-OutputTemporary }
    catch {
        if (-not $failure) { $failure = 'Output cleanup failed; no unverified path was deleted.' }
    }
    try { Remove-PrivateStage }
    catch {
        if (-not $failure) { $failure = 'Temporary cleanup failed; no unverified path was deleted.' }
    }
}
if ($failure) {
    Write-Host ('ERROR: ' + $failure)
    exit 1
}
