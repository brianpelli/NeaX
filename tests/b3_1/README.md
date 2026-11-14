# OFIKO B.3.1 automated checks

## Safe transactional suite

Run from the repository root in Windows PowerShell 5.1 or PowerShell 7:

```powershell
powershell.exe -NoProfile -File .\tests\b3_1\run.ps1
# Alternatively, with PowerShell 7:
pwsh -NoProfile -File .\tests\b3_1\run.ps1
```

The runner hard-codes `supabase_db_ofiko-local`, checks the repository project ID, verifies PostgreSQL 17.11 and the registered B.3.1 migration, and refuses another container or database. It displays `NOTICE: APROBADO` messages and real error diagnostics, while suppressing SQL result rows such as synthetic UUIDs.

`transactional.sql` creates synthetic Auth users and related rows inside one transaction. It exercises B.1 contact reuse/confirmation, B.2 own-contact visibility, B.3 publication validation, suspension, editing, authorization, retirement, RLS, reputation views, and audit detachment after a synthetic review delete. The script ends with `ROLLBACK`; closing the psql connection also rolls back if an assertion fails. The runner compares counts of affected persistent tables before and after.

The transactional battery was executed successfully against the local Supabase database: **44 cases APROBADO**, the transaction ended with `ROLLBACK`, and the runner confirmed that persistent row counts matched before and after. B.3.1 can be closed locally with the concurrency limitation below documented.

## Concurrency cases

The two-publication race, two-edit race, and audit consistency under concurrent failure remain **NO VERIFICADO**. C01, C02, and C03 require committed fixtures visible to two independent PostgreSQL connections. These are pending validation before deploying B.3.1 to production.

- `C01` — concurrent publications for one client-professional pair: **NO VERIFICADO**.
- `C02` — concurrent edits at the three-edit limit: **NO VERIFICADO**.
- `C03` — audit state after concurrent failure: **NO VERIFICADO**.

Run these cases only in a disposable, isolated Supabase test database created from the same migrations, with synthetic users and no copied personal data. Coordinate two independent psql sessions with an explicit barrier; verify SQLSTATE, final review count/edit count, and audit ordinal count; then destroy only that disposable database after confirming its identity. Do not run them against production, A.6, or the existing local development database.

## Result states

- **APROBADO**: an assertion completed successfully in the transactional suite.
- **FALLIDO**: an assertion failed; psql exits and rolls back the transaction.
- **NO VERIFICADO**: Docker or preflight is unavailable, or a concurrency case has not been run in the isolated database described above.
