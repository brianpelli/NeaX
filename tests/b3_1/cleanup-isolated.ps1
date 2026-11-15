[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$projectId = 'ofiko-b3-test'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$tempRoot = Join-Path $env:TEMP $projectId
$cli = Join-Path $repoRoot 'node_modules\.bin\supabase.cmd'
$docker = (Get-Command docker -ErrorAction Stop).Source
$protectedVolumes = @('supabase_db_ofiko-local','supabase_edge_runtime_ofiko-local','supabase_storage_ofiko-local')
$beforeProtected = @(& $docker volume ls --format '{{.Name}}' | Where-Object { $protectedVolumes -contains $_ } | Sort-Object)
$containers = @(& $docker ps -a --filter "name=ofiko-b3-test" --format '{{.Names}}')
foreach ($name in $containers) {
  if ($name -notmatch "_$projectId$") { throw "Refusing cleanup: unexpected container '$name'." }
$labelJson = & $docker inspect --format '{{json .Config.Labels}}' $name
  $label = ($labelJson | ConvertFrom-Json).'com.docker.compose.project'
  if ($label -ne $projectId) { throw "Refusing cleanup: project label mismatch on '$name'." }
}
$volumes = @(& $docker volume ls --format '{{.Name}}' | Where-Object { $_ -match "_$projectId$" })
foreach ($name in $volumes) {
$labelJson = & $docker volume inspect --format '{{json .Labels}}' $name
  $label = ($labelJson | ConvertFrom-Json).'com.docker.compose.project'
  if ($label -ne $projectId) { throw "Refusing cleanup: project label mismatch on volume '$name'." }
}
if (-not (Test-Path -LiteralPath (Join-Path $tempRoot 'supabase\config.toml'))) { throw 'Refusing cleanup: exact disposable config not found.' }
$config = Get-Content -Raw -LiteralPath (Join-Path $tempRoot 'supabase\config.toml')
if ($config -notmatch '(?m)^project_id\s*=\s*"ofiko-b3-test"\s*$') { throw 'Refusing cleanup: config project_id mismatch.' }
& $cli stop --project-id $projectId --no-backup --workdir $tempRoot
if ($LASTEXITCODE -ne 0) { throw 'Supabase CLI could not stop the exact test project.' }
$afterContainers = @(& $docker ps -a --filter "name=ofiko-b3-test" --format '{{.Names}}')
$afterVolumes = @(& $docker volume ls --format '{{.Name}}' | Where-Object { $_ -match "_$projectId$" })
if ($afterContainers.Count -or $afterVolumes.Count) { throw "Disposable resources remain: $($afterContainers -join ',') $($afterVolumes -join ',')" }
$afterProtected = @(& $docker volume ls --format '{{.Name}}' | Where-Object { $protectedVolumes -contains $_ } | Sort-Object)
if (Compare-Object $beforeProtected $afterProtected) { throw 'Protected volumes changed during cleanup.' }
Remove-Item -LiteralPath $tempRoot -Recurse -Force
Write-Host 'Disposable project resources and temporary files removed.'
Write-Host 'Protected ofiko-local volumes remain unchanged.'
