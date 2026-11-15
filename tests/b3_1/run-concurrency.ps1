[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$projectId = 'ofiko-b3-test'
$container = 'supabase_db_ofiko-b3-test'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$instanceRoot = Join-Path $env:TEMP 'ofiko-b3-test'
$configPath = Join-Path $instanceRoot 'supabase\config.toml'
$cli = Join-Path $repoRoot 'node_modules\.bin\supabase.cmd'
$docker = (Get-Command docker -ErrorAction Stop).Source
if (-not (Test-Path -LiteralPath $configPath)) { throw 'Disposable config missing; no concurrency tests run.' }
$config = Get-Content -Raw -LiteralPath $configPath
if ($config -notmatch '(?m)^project_id\s*=\s*"ofiko-b3-test"\s*$') { throw 'Project ID mismatch; refusing to test.' }
$identity = & $docker inspect --format '{{.Name}}|{{.State.Running}}' $container
if ($LASTEXITCODE -ne 0 -or $identity.Trim() -ne "/$container|true") { throw 'Exact disposable database is not running; no tests run.' }

function Invoke-TestSql([string]$Sql) {
  $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Sql))
  $shell = "printf '%s' '$encoded' | base64 -d | psql -X -qAt -v ON_ERROR_STOP=1 -v VERBOSITY=verbose -U postgres -d postgres -f -"
  $previousPreference = $ErrorActionPreference
  try {
    $ErrorActionPreference = 'Continue'
    $output = & $docker exec $container bash -lc $shell 2>&1
    $exitCode = $LASTEXITCODE
  } finally { $ErrorActionPreference = $previousPreference }
  if ($exitCode -ne 0) { throw "Disposable SQL failed (exit $exitCode) for [$Sql]: $($output -join ' ')" }
  return ($output -join "`n").Trim()
}
function Start-TestSession([string]$Sql) {
  return Start-Job -ArgumentList $docker, $container, $Sql -ScriptBlock {
    param($dockerPath, $dbContainer, $statement)
    $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($statement))
    $shell = "printf '%s' '$encoded' | base64 -d | psql -X -qAt -v ON_ERROR_STOP=1 -v VERBOSITY=verbose -U postgres -d postgres -f -"
    $output = & $dockerPath exec $dbContainer bash -lc $shell 2>&1
    [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = ($output -join "`n") }
  }
}
function Wait-TestJobs($Jobs, [int]$TimeoutSeconds = 15) {
  $completed = Wait-Job -Job $Jobs -Timeout $TimeoutSeconds
  if (@($Jobs | Where-Object State -eq 'Running').Count -gt 0) {
    Stop-Job -Job $Jobs -ErrorAction SilentlyContinue
    throw "Concurrency session timeout after ${TimeoutSeconds}s."
  }
  $results = @($Jobs | Receive-Job)
  Remove-Job -Job $Jobs -Force
  return $results
}
function Assert-Race($Results, [string]$ExpectedSqlState, [string]$Case) {
  $success = @($Results | Where-Object ExitCode -eq 0).Count
  $failed = @($Results | Where-Object ExitCode -ne 0)
  if ($success -ne 1 -or $failed.Count -ne 1 -or $failed[0].Output -notmatch $ExpectedSqlState) {
    throw "$Case expected one success and one SQLSTATE $ExpectedSqlState; results: $($Results | ForEach-Object { "$($_.ExitCode):$($_.Output)" } -join ' || ')"
  }
}

$ids = @{}
foreach ($key in 'client1','professionalUser1','professional1','attempt1','client2','professionalUser2','professional2','attempt2') {
  $ids[$key] = [guid]::NewGuid().ToString()
}
$run = [guid]::NewGuid().ToString('N')
$created = $false
$failure = $null
try {
  $setup = @"
BEGIN;
INSERT INTO auth.users (id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data)
VALUES
 ('$($ids.client1)','authenticated','authenticated','b3c01+$run@example.invalid','',now(),'{}'::jsonb,'{"full_name":"C01 client"}'::jsonb),
 ('$($ids.professionalUser1)','authenticated','authenticated','b3p01+$run@example.invalid','',now(),'{}'::jsonb,'{"full_name":"C01 pro"}'::jsonb),
 ('$($ids.client2)','authenticated','authenticated','b3c03+$run@example.invalid','',now(),'{}'::jsonb,'{"full_name":"C03 client"}'::jsonb),
 ('$($ids.professionalUser2)','authenticated','authenticated','b3p03+$run@example.invalid','',now(),'{}'::jsonb,'{"full_name":"C03 pro"}'::jsonb);
INSERT INTO public.professionals (id,user_id,category_id,is_suspended) VALUES
 ('$($ids.professional1)','$($ids.professionalUser1)',1,false),
 ('$($ids.professional2)','$($ids.professionalUser2)',1,false);
INSERT INTO public.professional_contact_attempts (id,professional_id,client_id,attempted_at,confirmed_at) VALUES
 ('$($ids.attempt1)','$($ids.professional1)','$($ids.client1)',now()-interval '1 minute',now()),
 ('$($ids.attempt2)','$($ids.professional2)','$($ids.client2)',now()-interval '1 minute',now());
COMMIT;
"@
  Invoke-TestSql $setup | Out-Null
  $created = $true

  $createSql = "SET statement_timeout='12s'; SET request.jwt.claim.sub='$($ids.client1)'; SELECT pg_sleep(0.25); SELECT public.create_professional_review('$($ids.attempt1)'::uuid,4::smallint,'C01 concurrent');"
  $jobs = @((Start-TestSession $createSql),(Start-TestSession $createSql))
  $c01 = Wait-TestJobs $jobs 15
  Assert-Race $c01 '23505' 'C01'
  $c01Count = Invoke-TestSql "SELECT count(*) FROM public.reviews WHERE client_id='$($ids.client1)'::uuid AND professional_id='$($ids.professional1)'::uuid"
  if ($c01Count -ne '1') { throw "C01 persisted $c01Count reviews, expected one." }
  Write-Host 'APROBADO C01: two sessions published one review; the other received 23505.'
  $review1 = Invoke-TestSql "SELECT id FROM public.reviews WHERE client_id='$($ids.client1)'::uuid AND professional_id='$($ids.professional1)'::uuid"

  $historySetup = @"
UPDATE public.reviews SET overall_rating=4, comment='C02 baseline', edit_count=2 WHERE id='$review1'::uuid;
INSERT INTO public.review_edit_history (review_id,review_ref,editor_id,edit_ordinal,old_overall_rating,new_overall_rating,old_comment,new_comment,edited_at)
VALUES
 ('$review1','$review1','$($ids.client1)',1,3,4,'a','b',now()-interval '2 minutes'),
 ('$review1','$review1','$($ids.client1)',2,3,4,'b','C02 baseline',now()-interval '1 minute');
"@
  Invoke-TestSql $historySetup | Out-Null
  $edit1 = "SET statement_timeout='12s'; SET request.jwt.claim.sub='$($ids.client1)'; SELECT pg_sleep(0.25); SELECT public.edit_professional_review('$review1'::uuid,3::smallint,'C02 edit A');"
  $edit2 = "SET statement_timeout='12s'; SET request.jwt.claim.sub='$($ids.client1)'; SELECT pg_sleep(0.25); SELECT public.edit_professional_review('$review1'::uuid,5::smallint,'C02 edit B');"
  $jobs = @((Start-TestSession $edit1),(Start-TestSession $edit2))
  $c02 = Wait-TestJobs $jobs 15
  Assert-Race $c02 '23514' 'C02'
  $state = Invoke-TestSql "SELECT edit_count||'|'||(SELECT count(*) FROM public.review_edit_history WHERE review_ref='$review1'::uuid)||'|'||(SELECT max(edit_ordinal) FROM public.review_edit_history WHERE review_ref='$review1'::uuid) FROM public.reviews WHERE id='$review1'::uuid"
  if ($state -ne '3|3|3') { throw "C02 final state mismatch: $state" }
  Write-Host 'APROBADO C02: only one of two edits at count two persisted; count and history end at three.'

  $createC03 = "SET request.jwt.claim.sub='$($ids.client2)'; SELECT public.create_professional_review('$($ids.attempt2)'::uuid,3::smallint,'C03 baseline');"
  $review2 = Invoke-TestSql $createC03
  $triggerSql = @"
CREATE OR REPLACE FUNCTION public.b3_test_fail_review_update() RETURNS trigger LANGUAGE plpgsql SET search_path='' AS `$fn`$
BEGIN
  IF OLD.id = '$review2'::uuid AND current_setting('b3test.c03_fail', true) = 'on' THEN
    RAISE EXCEPTION 'forced C03 update failure' USING ERRCODE='P0001';
  END IF;
  RETURN NEW;
END;`$fn`$;
CREATE TRIGGER b3_test_fail_review_update BEFORE UPDATE ON public.reviews FOR EACH ROW EXECUTE FUNCTION public.b3_test_fail_review_update();
"@
  Invoke-TestSql $triggerSql | Out-Null
  $holderSql = @"
SET application_name='b3-c03-holder';
BEGIN;
SELECT id FROM public.reviews WHERE id='$review2'::uuid FOR UPDATE;
SELECT pg_sleep(4);
SET request.jwt.claim.sub='$($ids.client2)';
SELECT set_config('b3test.c03_fail','on',true);
DO `$c03`$
DECLARE v_failed boolean := false;
BEGIN
  BEGIN
    PERFORM public.edit_professional_review('$review2'::uuid,4::smallint,'C03 failing edit');
  EXCEPTION WHEN SQLSTATE 'P0001' THEN
    v_failed := true;
  END;
  IF NOT v_failed THEN RAISE EXCEPTION 'C03 failure trigger did not run' USING ERRCODE='P0002'; END IF;
  RAISE NOTICE 'C03 forced failure occurred after history insert';
END;`$c03`$;
SELECT set_config('b3test.c03_fail','off',true);
COMMIT;
"@
  $waiterSql = "SET application_name='b3-c03-waiter'; SET statement_timeout='12s'; SET request.jwt.claim.sub='$($ids.client2)'; SELECT public.edit_professional_review('$review2'::uuid,5::smallint,'C03 winning edit');"
  $holder = Start-TestSession $holderSql
  $holderStarted = $false
  for ($i=0; $i -lt 25; $i++) {
    $activity = Invoke-TestSql "SELECT count(*) FROM pg_catalog.pg_stat_activity WHERE application_name='b3-c03-holder' AND state='active'"
    if ($activity -eq '1') { $holderStarted = $true; break }
    Start-Sleep -Milliseconds 100
  }
  if (-not $holderStarted) { Stop-Job $holder -ErrorAction SilentlyContinue; throw 'C03 holder session did not start.' }
  $waiter = Start-TestSession $waiterSql
  $waiting = $false
  for ($i=0; $i -lt 30; $i++) {
    $activity = Invoke-TestSql "SELECT count(*) FROM pg_catalog.pg_stat_activity WHERE application_name='b3-c03-waiter' AND wait_event_type='Lock'"
    if ($activity -eq '1') { $waiting = $true; break }
    Start-Sleep -Milliseconds 100
  }
  if (-not $waiting) {
    Stop-Job @($holder,$waiter) -ErrorAction SilentlyContinue
    throw 'C03 waiter did not reach the row lock within 3 seconds.'
  }
  $c03 = Wait-TestJobs @($holder,$waiter) 15
  if (@($c03 | Where-Object ExitCode -ne 0).Count -ne 0 -or ($c03 | ForEach-Object Output | Out-String) -notmatch 'forced failure occurred after history insert') {
    throw "C03 session failure or expected exception missing: $($c03 | ForEach-Object { $_.Output } -join ' || ')"
  }
  $state = Invoke-TestSql "SELECT edit_count||'|'||(SELECT count(*) FROM public.review_edit_history WHERE review_ref='$review2'::uuid)||'|'||(SELECT max(edit_ordinal) FROM public.review_edit_history WHERE review_ref='$review2'::uuid)||'|'||(SELECT overall_rating FROM public.reviews WHERE id='$review2'::uuid) FROM public.reviews WHERE id='$review2'::uuid"
  if ($state -ne '1|1|1|5') { throw "C03 rollback/second edit state mismatch: $state" }
  Write-Host 'APROBADO C03: the failing transaction rolled back its history and row update; the waiting edit committed alone.'
} catch {
  $failure = $_
} finally {
  if ($created) {
    & $cli db reset --workdir $instanceRoot --yes | Out-Null
    if ($LASTEXITCODE -ne 0) { $failure = "Disposable reset failed during cleanup; synthetic concurrency fixtures may remain. $failure" }
  }
}
if ($failure) { throw $failure }
$counts = Invoke-TestSql "SELECT (SELECT count(*) FROM auth.users)||'|'||(SELECT count(*) FROM public.reviews)||'|'||(SELECT count(*) FROM public.review_edit_history)||'|'||(SELECT count(*) FROM public.review_moderation_audit)||'|'||(SELECT count(*) FROM public.categories)"
if ($counts -ne '0|0|0|0|43') { throw "Disposable reset verification failed: $counts" }
Write-Host 'Disposable database reset verified: no synthetic users/reviews/audit remain; 43 catalog rows remain.'
