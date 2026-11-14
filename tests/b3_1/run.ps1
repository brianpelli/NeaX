[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$allowedContainer = 'supabase_db_ofiko-local'
$expectedProjectId = 'ofiko-local'
$migrationVersion = '20261114002851'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$configPath = Join-Path $repoRoot 'supabase\config.toml'
$sqlPath = Join-Path $PSScriptRoot 'transactional.sql'

if (-not (Test-Path -LiteralPath $configPath)) {
  throw 'Supabase config.toml was not found; refusing to run.'
}
if (-not (Test-Path -LiteralPath $sqlPath)) {
  throw 'transactional.sql was not found; refusing to run.'
}

$configText = Get-Content -Raw -LiteralPath $configPath
if ($configText -notmatch '(?m)^project_id\s*=\s*"ofiko-local"\s*$') {
  throw "Project config is not explicitly $expectedProjectId; refusing to run."
}

$docker = Get-Command docker -ErrorAction SilentlyContinue
if (-not $docker -or $docker.CommandType -ne 'Application') {
  throw 'Docker CLI is unavailable; no tests were run.'
}
$dockerPath = $docker.Source

function ConvertTo-WindowsArgument([string]$Value) {
  $builder = New-Object System.Text.StringBuilder
  [void]$builder.Append('"')
  $backslashCount = 0

  for ($index = 0; $index -lt $Value.Length; $index++) {
    $character = $Value[$index]
    if ($character -eq [char]92) {
      $backslashCount++
      continue
    }

    if ($character -eq [char]34) {
      if ($backslashCount -gt 0) {
        [void]$builder.Append(('\' * (2 * $backslashCount)))
      }
      [void]$builder.Append([char]34)
      $backslashCount = 0
      continue
    }

    if ($backslashCount -gt 0) {
      [void]$builder.Append(('\' * $backslashCount))
      $backslashCount = 0
    }
    [void]$builder.Append($character)
  }

  if ($backslashCount -gt 0) {
    [void]$builder.Append(('\' * (2 * $backslashCount)))
  }
  [void]$builder.Append('"')
  return $builder.ToString()
}

function Invoke-NativeProcess(
  [string]$FilePath,
  [string[]]$Arguments,
  [string]$InputText
) {
  $startInfo = New-Object System.Diagnostics.ProcessStartInfo
  $startInfo.FileName = $FilePath
  $startInfo.Arguments = (($Arguments | ForEach-Object {
    ConvertTo-WindowsArgument ([string]$_)
  }) -join ' ')
  $startInfo.UseShellExecute = $false
  $startInfo.CreateNoWindow = $true
  $startInfo.RedirectStandardOutput = $true
  $startInfo.RedirectStandardError = $true
  $startInfo.RedirectStandardInput = ($null -ne $InputText)

  $process = New-Object System.Diagnostics.Process
  $process.StartInfo = $startInfo

  try {
    if (-not $process.Start()) {
      throw "Could not start native command '$FilePath'."
    }

    # Drain both pipes asynchronously so neither can block the child process.
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()

    if ($null -ne $InputText) {
      $process.StandardInput.Write($InputText)
      $process.StandardInput.Close()
    }

    $process.WaitForExit()
    $stdout = $stdoutTask.Result
    $stderr = $stderrTask.Result

    return [pscustomobject]@{
      ExitCode = $process.ExitCode
      StdOut = $stdout
      StdErr = $stderr
    }
  }
  finally {
    $process.Dispose()
  }
}

function Write-TestFeedback($Result, [switch]$IncludeErrors) {
  $approvedPattern = 'NOTICE:\s+APROBADO\b'
  $errorPattern = '(?i)^\s*(?:ERROR|FATAL|PANIC|DETAIL|CONTEXT|HINT):|\b(?:psql|docker)(?:\.exe)?\b.*\berror\b|error response from daemon'

  foreach ($line in ($Result.StdErr -split '\r?\n')) {
    if ($line -match $approvedPattern -or ($IncludeErrors -and $line -match $errorPattern)) {
      Write-Host $line
    }
  }

  if ($IncludeErrors) {
    foreach ($line in ($Result.StdOut -split '\r?\n')) {
      if ($line -match $errorPattern) {
        Write-Host $line
      }
    }
  }
}

function Invoke-LocalPsql([string]$Sql, [switch]$FromStdin, [switch]$ShowOutput) {
  $arguments = @('exec')
  if ($FromStdin) {
    $arguments += '-i'
  }
  $arguments += @(
    $allowedContainer, 'psql', '-X', '-qAt', '-v', 'ON_ERROR_STOP=1',
    '-U', 'postgres', '-d', 'postgres'
  )
  if (-not $FromStdin) {
    $arguments += @('-c', $Sql)
  }

  $inputText = $null
  if ($FromStdin) {
    $inputText = $Sql
  }
  try {
    $result = Invoke-NativeProcess $dockerPath $arguments $inputText
  } catch {
    throw "FALLIDO: could not run local psql command. $($_.Exception.Message)"
  }

  # PostgreSQL NOTICE output is on stderr. Show approvals and diagnostics,
  # while keeping psql result rows (including synthetic UUIDs) out of the log.
  if ($ShowOutput -or $result.ExitCode -ne 0) {
    Write-TestFeedback $result -IncludeErrors:($result.ExitCode -ne 0)
  }

  if ($result.ExitCode -ne 0) {
    $details = $result.StdErr.Trim()
    throw "FALLIDO: local psql command exited with code $($result.ExitCode). $details"
  }

  if ($ShowOutput) {
    return
  }
  return $result.StdOut.Trim()
}

$identityResult = Invoke-NativeProcess $dockerPath @(
  'inspect', '--format', '{{.Name}}|{{.State.Running}}', $allowedContainer
) $null
if (-not [string]::IsNullOrEmpty($identityResult.StdErr)) {
  Write-Host $identityResult.StdErr -NoNewline
}
if ($identityResult.ExitCode -ne 0) {
  if (-not [string]::IsNullOrEmpty($identityResult.StdOut)) {
    Write-Host $identityResult.StdOut -NoNewline
  }
  throw "FALLIDO: could not inspect the allowed local container '$allowedContainer'; no tests were run."
}
$identity = $identityResult.StdOut.Trim()
if ($identity -ne "/$allowedContainer|true") {
  throw "Container identity mismatch; expected only '/$allowedContainer|true'. No tests were run."
}

$serverVersion = Invoke-LocalPsql 'SHOW server_version'
if ($serverVersion -notmatch '^17\.11(?:\D|$)') {
  throw "Expected local PostgreSQL 17.11, found '$serverVersion'; no tests were run."
}

$preflightSql = @"
SELECT CASE
  WHEN current_database() <> 'postgres' THEN 'wrong_database'
  WHEN to_regclass('public.review_edit_history') IS NULL THEN 'missing_b3_schema'
  WHEN NOT EXISTS (
    SELECT 1 FROM supabase_migrations.schema_migrations
    WHERE version = '$migrationVersion'
  ) THEN 'migration_not_registered'
  ELSE 'ready'
END
"@
$preflight = Invoke-LocalPsql $preflightSql
if ($preflight -ne 'ready') {
  throw "Local database preflight returned '$preflight'; no tests were run."
}

$countsSql = @'
SELECT pg_catalog.concat_ws('|',
  (SELECT count(*) FROM auth.users),
  (SELECT count(*) FROM public.profiles),
  (SELECT count(*) FROM public.professionals),
  (SELECT count(*) FROM public.professional_contact_attempts),
  (SELECT count(*) FROM public.professional_contacts),
  (SELECT count(*) FROM public.hirings),
  (SELECT count(*) FROM public.reviews),
  (SELECT count(*) FROM public.review_edit_history),
  (SELECT count(*) FROM public.admins)
)
'@
$before = Invoke-LocalPsql $countsSql
$testError = $null
$sql = Get-Content -Raw -LiteralPath $sqlPath

try {
  Invoke-LocalPsql $sql -FromStdin -ShowOutput
} catch {
  $testError = $_
} finally {
  $after = Invoke-LocalPsql $countsSql
  if ($before -ne $after) {
    throw 'FALLIDO: persistent row counts changed during the rollback suite; stop and inspect the local test database.'
  }
}

if ($testError) {
  throw $testError
}

Write-Host 'Persistent row counts match before and after the transaction suite.'
Write-Host 'Concurrency tests were not included; see README.md for the safe isolation requirement.'
