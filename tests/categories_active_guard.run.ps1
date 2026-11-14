[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$allowedContainer = 'supabase_db_ofiko-desktop'
$expectedProjectId = 'ofiko-desktop'
$guardMigrationVersion = '20261114192856'
$migrationVersion = '20261114194245'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$configPath = Join-Path $repoRoot 'supabase\config.toml'
$sqlPath = Join-Path $PSScriptRoot 'categories_active_guard.sql'

if (-not (Test-Path -LiteralPath $configPath)) {
  throw 'Supabase config.toml was not found; refusing to run.'
}
if (-not (Test-Path -LiteralPath $sqlPath)) {
  throw 'Test SQL was not found; refusing to run.'
}
$configText = Get-Content -Raw -LiteralPath $configPath
if ($configText -notmatch '(?m)^project_id\s*=\s*"ofiko-desktop"\s*$') {
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
    if ($character -eq [char]92) { $backslashCount++; continue }
    if ($character -eq [char]34) {
      if ($backslashCount -gt 0) { [void]$builder.Append(('\' * (2 * $backslashCount))) }
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
  if ($backslashCount -gt 0) { [void]$builder.Append(('\' * (2 * $backslashCount))) }
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
    if (-not $process.Start()) { throw "Could not start '$FilePath'." }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    if ($null -ne $InputText) {
      $process.StandardInput.Write($InputText)
      $process.StandardInput.Close()
    }
    $process.WaitForExit()
    return [pscustomobject]@{
      ExitCode = $process.ExitCode
      StdOut = $stdoutTask.Result
      StdErr = $stderrTask.Result
    }
  } finally {
    $process.Dispose()
  }
}

function Invoke-LocalPsql([string]$Sql, [switch]$FromStdin) {
  $arguments = @('exec')
  if ($FromStdin) { $arguments += '-i' }
  $arguments += @(
    $allowedContainer, 'psql', '-X', '-qAt', '-v', 'ON_ERROR_STOP=1',
    '-U', 'postgres', '-d', 'postgres'
  )
  if (-not $FromStdin) { $arguments += @('-c', $Sql) }
  $inputText = $null
  if ($FromStdin) { $inputText = $Sql }
  $result = Invoke-NativeProcess $dockerPath $arguments $inputText
  if ($result.ExitCode -ne 0) {
    throw "Local psql failed; no tests were run or the transaction rolled back. $($result.StdErr.Trim())"
  }
  if (-not $FromStdin) { return $result.StdOut.Trim() }
  foreach ($line in ($result.StdErr -split '\r?\n')) {
    if ($line -match 'NOTICE:\s+APROBADO\b') { Write-Host $line }
    elseif ($line -match '^\s*(?:ERROR|FATAL|PANIC|DETAIL|CONTEXT|HINT):') { Write-Host $line }
  }
}

$identityResult = Invoke-NativeProcess $dockerPath @(
  'inspect', '--format', '{{.Name}}|{{.State.Running}}', $allowedContainer
) $null
if ($identityResult.ExitCode -ne 0) {
  throw "Could not inspect '$allowedContainer'; no tests were run. $($identityResult.StdErr.Trim())"
}
if ($identityResult.StdOut.Trim() -ne "/$allowedContainer|true") {
  throw "Container identity mismatch; expected only '/$allowedContainer|true'. No tests were run."
}

$preflightSql = @"
SELECT CASE
  WHEN current_database() <> 'postgres' THEN 'wrong_database'
  WHEN to_regclass('public.categories') IS NULL
    OR to_regclass('public.professionals') IS NULL THEN 'missing_schema'
  WHEN (SELECT count(*) FROM public.categories) <> 43 THEN 'unexpected_category_total'
  WHEN (SELECT count(*) FROM public.categories WHERE is_active IS TRUE) <> 39 THEN 'unexpected_active_total'
  WHEN (SELECT count(*) FROM public.categories WHERE is_active IS FALSE) <> 4 THEN 'unexpected_inactive_total'
  WHEN (SELECT count(*) FROM supabase_migrations.schema_migrations
        WHERE version IN ('20261110235147','20261112223844','20261112232803','20261114002851')) <> 4
    THEN 'historical_migrations_not_registered'
  WHEN NOT EXISTS (SELECT 1 FROM supabase_migrations.schema_migrations WHERE version = '$guardMigrationVersion')
    THEN 'guard_migration_not_registered'
  WHEN NOT EXISTS (SELECT 1 FROM supabase_migrations.schema_migrations WHERE version = '$migrationVersion')
    THEN 'lock_migration_not_registered'
  WHEN to_regprocedure('public.enforce_professional_active_category()') IS NULL
    THEN 'guard_function_missing'
  WHEN NOT EXISTS (
    SELECT 1 FROM pg_catalog.pg_proc
     WHERE oid = 'public.enforce_professional_active_category()'::regprocedure
       AND prosecdef
       AND NOT has_function_privilege('authenticated', oid, 'EXECUTE')
  ) THEN 'guard_function_security_mismatch'
  WHEN NOT EXISTS (
    SELECT 1 FROM pg_catalog.pg_trigger
     WHERE tgrelid = 'public.professionals'::regclass
       AND tgname = 'professionals_active_category_guard'
       AND NOT tgisinternal AND tgenabled = 'O'
  ) THEN 'guard_trigger_missing_or_disabled'
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
  (SELECT count(*) FROM public.admins),
  (SELECT count(*) FROM public.categories)
)
'@
$before = Invoke-LocalPsql $countsSql
$sql = [System.IO.File]::ReadAllText($sqlPath, [System.Text.Encoding]::UTF8)
$testError = $null
try {
  Invoke-LocalPsql $sql -FromStdin
} catch {
  $testError = $_
} finally {
  $after = Invoke-LocalPsql $countsSql
  if ($before -ne $after) {
    throw 'Persistent row counts changed; stop and inspect the isolated local test database.'
  }
}
if ($testError) { throw $testError }

$postflight = Invoke-LocalPsql @'
SELECT CASE WHEN EXISTS (
  SELECT 1 FROM pg_catalog.pg_trigger
   WHERE tgrelid = 'public.professionals'::regclass
     AND tgname = 'professionals_active_category_guard'
     AND NOT tgisinternal AND tgenabled = 'O'
) THEN 'ready' ELSE 'guard_trigger_not_enabled_after_test' END
'@
if ($postflight -ne 'ready') {
  throw "Post-test trigger check returned '$postflight'; stop and inspect the local test database."
}

Write-Host 'All synthetic tests completed; persistent row counts match before and after ROLLBACK.'
