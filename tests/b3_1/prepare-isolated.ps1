[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$projectId = 'ofiko-b3-test'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$sourceSupabase = Join-Path $repoRoot 'supabase'
$tempRoot = Join-Path $env:TEMP $projectId
$targetSupabase = Join-Path $tempRoot 'supabase'
$cli = Join-Path $repoRoot 'node_modules\.bin\supabase.cmd'
$docker = (Get-Command docker -ErrorAction Stop).Source
if (-not (Test-Path -LiteralPath (Join-Path $sourceSupabase 'migrations\20261114224100_b3_review_moderation.sql'))) { throw 'Latest B.3 migration is missing.' }
if (Test-Path -LiteralPath $tempRoot) { throw "Refusing to overwrite existing test directory: $tempRoot" }
$found = @(& $docker ps -a --format '{{.Names}}' | Where-Object { $_ -eq "supabase_db_$projectId" })
if ($found.Count) { throw "Refusing to reuse container supabase_db_$projectId." }
$existingVolumes = @(& $docker volume ls --format '{{.Name}}' | Where-Object { $_ -match "_$projectId$" })
if ($existingVolumes.Count) { throw "Refusing to reuse volumes: $($existingVolumes -join ', ')" }
$ports = @(55320,55321,55322,55323,55324,55327,55329,58083)
$busy = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Where-Object { $ports -contains $_.LocalPort }
if ($busy) { throw "Disposable ports are occupied: $($busy.LocalPort -join ', ')" }
New-Item -ItemType Directory -Path (Join-Path $targetSupabase 'migrations') -Force | Out-Null
Get-ChildItem -LiteralPath (Join-Path $sourceSupabase 'migrations') -Filter '*.sql' | Sort-Object Name | Copy-Item -Destination (Join-Path $targetSupabase 'migrations')
Copy-Item -LiteralPath (Join-Path $sourceSupabase 'seed.sql') -Destination $targetSupabase
$configLines = @(
  'project_id = "ofiko-b3-test"', '', '[api]', 'port = 55321', 'schemas = ["public", "graphql_public"]', 'extra_search_path = ["public", "extensions"]', 'max_rows = 1000',
  '', '[db]', 'port = 55322', 'shadow_port = 55320', 'major_version = 17', 'health_timeout = "2m"',
  '', '[db.pooler]', 'enabled = false', 'port = 55329', 'pool_mode = "transaction"',
  '', '[db.migrations]', 'enabled = true', 'schema_paths = []', '', '[db.seed]', 'enabled = true', 'sql_paths = ["./seed.sql"]',
  '', '[studio]', 'enabled = true', 'port = 55323', 'api_url = "http://127.0.0.1"',
  '', '[local_smtp]', 'enabled = true', 'port = 55324',
  '', '[auth]', 'enabled = true', 'site_url = "http://localhost:3000"', 'additional_redirect_urls = ["http://localhost:3000", "http://127.0.0.1:3000"]', 'enable_signup = true',
  '', '[storage]', 'enabled = true', 'file_size_limit = "50MiB"', '', '[realtime]', 'enabled = true',
  '', '[edge_runtime]', 'enabled = true', 'inspector_port = 58083', 'deno_version = 2',
  '', '[analytics]', 'enabled = true', 'port = 55327', 'backend = "postgres"'
)
[IO.File]::WriteAllText((Join-Path $targetSupabase 'config.toml'), ($configLines -join "`n"), (New-Object Text.UTF8Encoding($false)))
$config = Get-Content -Raw -LiteralPath (Join-Path $targetSupabase 'config.toml')
if ($config -notmatch '(?m)^project_id\s*=\s*"ofiko-b3-test"\s*$') { throw 'Isolated project ID mismatch.' }
if ((Test-Path -LiteralPath (Join-Path $tempRoot '.env.local')) -or (Test-Path -LiteralPath (Join-Path $tempRoot '.env'))) { throw 'Environment file unexpectedly copied.' }
$sourceFiles = @(Get-ChildItem -LiteralPath (Join-Path $sourceSupabase 'migrations') -Filter '*.sql' | Sort-Object Name)
$copyFiles = @(Get-ChildItem -LiteralPath (Join-Path $targetSupabase 'migrations') -Filter '*.sql' | Sort-Object Name)
if ($sourceFiles.Count -ne $copyFiles.Count) { throw 'Migration count mismatch.' }
for ($i=0; $i -lt $sourceFiles.Count; $i++) {
  if ((Get-FileHash $sourceFiles[$i].FullName -Algorithm SHA256).Hash -ne (Get-FileHash $copyFiles[$i].FullName -Algorithm SHA256).Hash) { throw "Migration hash mismatch: $($sourceFiles[$i].Name)" }
}
if ((Get-FileHash (Join-Path $sourceSupabase 'seed.sql') -Algorithm SHA256).Hash -ne (Get-FileHash (Join-Path $targetSupabase 'seed.sql') -Algorithm SHA256).Hash) { throw 'Seed hash mismatch.' }
& $cli start --workdir $tempRoot | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Supabase CLI could not start the disposable instance.' }
& $cli db reset --workdir $tempRoot --yes | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Fresh migration or UTF-8 seed failed.' }
Write-Host "Disposable instance initialized: $projectId"
Write-Host "Temporary path: $tempRoot"
Write-Host 'No environment credentials or database dumps were copied.'
