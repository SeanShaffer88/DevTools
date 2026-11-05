# Policy regression evidence

Original sanitized fixtures; no upstream code copied. These are summaries, not
byte-for-byte transcripts. No private path, command arguments or identity retained.

- `policy-script-restriction.json`: architecture launch recorded in the approved
  `tasks/plan.md` reconciliation: Windows PowerShell 5.1 `-File` failed with
  UnauthorizedAccess, native exit 1; the PS7 launch succeeded without policy mutation.
  Expected diagnosis ScriptPolicyRestriction, Pass/0; no original operation retry.
- `policy-backend-omission.json`: assigned historical worker-routing regression,
  sandbox backend omitted despite a configured Windows sandbox. Original failure
  log was not supplied to this worker. This synthetic sanitized reproduction must
  remain PolicyUnknown/3; configuration presence alone cannot prove policy denial.

Both fixtures are exercised by tests/Test-ReliabilityNativePolicy.ps1. They establish
classifier behavior, not a live restriction or independent historical reproduction.
