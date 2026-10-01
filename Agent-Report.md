## Phase 1 verification result

Database test result: **PASS — 2/2**

A real testability defect was found and fixed:

- `AppDatabase.forTesting(path)` existed, but `openDatabase` still hardcoded the default path.
- This caused isolated tests to share `flowly.db`.
- Fixed `openDatabase` to use `await databasePath`.
- Production behavior is unchanged because the singleton’s path remains the normal platform database path.

Executed database suite:

```text
flutter test test/transfer_reconciliation_database_test.dart --reporter expanded
```

Final output:

```text
00:00 +0: strong pair links, preserves snapshots, balances and unlink restores metadata
00:01 +1: possible candidate persists, rejects idempotently, and has no raw SMS columns
00:01 +2: All tests passed!
```

| Requirement | Automated status |
|---|---|
| Strong matching | PASS |
| Candidate persistence | PASS |
| Candidate uniqueness | PASS |
| Auto-link | PASS |
| Reject | PASS |
| Link snapshot | PASS |
| Unlink restoration | PASS |
| Timestamp preservation | PASS |
| Source balance | PASS |
| Destination balance | PASS |
| Net-worth invariance | PASS |
| Raw SMS privacy | PASS |
| DB close/reopen persistence | PASS |
| Manual confirm | NOT TESTED |
| Analytics exclusion | NOT TESTED |
| Category-spending exclusion | NOT TESTED |
| Merchant-spending exclusion | NOT TESTED |
| Savings exclusion | NOT TESTED |
| Budget exclusion | NOT TESTED |
| Same-account safety | NOT TESTED |
| Currency mismatch safety | NOT TESTED |
| Amount mismatch safety | NOT TESTED |
| Timestamp-window safety | NOT TESTED |
| Multiple-candidate ambiguity | NOT TESTED |
| Missing timestamp safety | NOT TESTED |
| Missing provider mapping safety | NOT TESTED |

Previously verified:

- Sanity test: **1/1 PASS**
- Reconciliation service test: **4/4 PASS**

Phase 1 status: **PARTIALLY FIXED** — the database persistence core is now executed and verified, but the remaining required safety/accounting exclusion matrix has not yet been added or run.