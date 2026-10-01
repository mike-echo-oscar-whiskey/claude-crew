```json
{
  "schema": 1,
  "kind": "bug",
  "title": "🐛 fix(tests): the API host of NoAutoCreateFixture hangs in dispose after Wolverine stopped its listeners — the first stall with a name",
  "role": "qa-engineer",
  "blockedBy": [],
  "proves": [],
  "files": [
    {
      "path": "tests/Vonk.Api.IntegrationTests/VonkApiFixture.cs",
      "note": "DisposeAsync (:251, :269) is where all three occurrences hang; the fix lives in its Wolverine shutdown configuration or a Wolverine option"
    },
    {
      "path": "tests/Vonk.Api.IntegrationTests/TeardownBound.cs",
      "note": "a Task snapshot from inside the bound before it throws, to name the awaited call"
    }
  ]
}
```

## TL;DR

A full gate can end with every test green and still exit red, because one integration fixture's API host does not finish shutting down inside three minutes; after the fix every fixture's dispose returns in seconds.

## In one paragraph

`VonkApiFixture.DisposeAsync` stops the host, and after Wolverine has reported every listener stopped the host's `StopAsync` waits on something that never returns, until the 180 s teardown bound (#345) throws a named `TimeoutException`. `WebApplicationFactory` never awaits the DI container's disposal, so the only place a fixture can hang is `Host.StopAsync` — a hosted service whose `StopAsync` ignores the token, which here means Wolverine's runtime stop after the listeners are down: agent and leadership teardown, node persistence, or the `pg_advisory_unlock` the earlier sightings froze on. Three fixtures have now hung the same way (`NoAutoCreateFixture`, `ProvisioningSplitFixture`, the schema-gate seeding host), all through `VonkApiFixture.DisposeAsync`, so the hang is in the shared fixture's host dispose and not one fixture's. It has cost eleven unnamed sightings under #345, one red gate on a branch that touched no fixture, and one gate rerun per occurrence since. The work is qa-engineer's with event-sourcing-engineer for the Wolverine side: find what `Host.StopAsync` waits on with a dump of the host's threads or tasks at the moment the bound fires, then fix the hang or bound the offending stop with a named failure; whether the stall depends on machine load is part of the question.

## Evidence

First occurrence, 2026-09-17 14:0x, the first full gate after #589 merged, on `task/542-active-tenant-predicate` at 7151279f:

```
[Test Class Cleanup Failure (Vonk.Api.IntegrationTests.ManagedHostReadSurfaceTests)] Xunit.Sdk.TestPipelineException
  Class fixture type 'Vonk.Api.IntegrationTests.NoAutoCreateFixture' threw in DisposeAsync
  ---- System.TimeoutException : NoAutoCreateFixture of ManagedHostReadSurfaceTests API host dispose did not finish inside 180 s (#345). …
    TeardownBound.cs(43,0): at Vonk.Api.IntegrationTests.TeardownBound.RunAsync(String what, TimeSpan bound, Func`1 teardown)
    VonkApiFixture.cs(251,0): at Vonk.Api.IntegrationTests.VonkApiFixture.DisposeAsync()
    TenantSchemaWithoutAutoCreateTests.cs(56,0): at Vonk.Api.IntegrationTests.NoAutoCreateFixture.DisposeAsync()
```

The host's last lines before the silence are the sightings' signature exactly: `Application stopping signal received` → `Application is shutting down...` → `Stopped message listener at stub://replies/`, `…postgresql://vonk_ingestion/`, `Reassigned 44 incoming messages … vonk_tenants/`, `Stopped message listener at postgresql://vonk_tenants/`, `Reassigned 22 … vonk_provisioning/`, `Stopped message listener at postgresql://vonk_provisioning/` (each listener twice) — then nothing until the bound. The run finished (`Total: 579, Errors: 1, Failed: 0`, 344 s against the usual 180–210 s) and the gate exited 1 in 6 minutes, as #589 intended. One gate alone on the lock (#577), load average 2–6 falling from an earlier peak. Full integration log in the lead's scratchpad as `integration-stall-named-20260917.log` (line 61678); gate log `gates-542a-lead.log`.

Second occurrence, 2026-09-17 ~18:10, on the #608 tree (1e8164a0, the machine otherwise idle): `[Test Class Cleanup Failure (Vonk.Api.IntegrationTests.ProvisioningSplitTests)] … ProvisioningSplitFixture of ProvisioningSplitTests API host dispose did not finish inside 180 s (#345)` — `TeardownBound.RunAsync` ← `VonkApiFixture.DisposeAsync` (VonkApiFixture.cs:251, :269); the last lines before it are Wolverine stopping the `vonk_provisioning` listener twice. Every test passed. Log: `integration-stall-named-provisioningsplit-20260917.log`.

Third occurrence, 2026-09-17 ~19:35, on the #596 tree (first gate run): `TenantSchemaGateTests.ATenantBehindTheVersion_Gets503_… [FAIL] System.TimeoutException : TenantSchemaGateTests seeding host dispose did not finish inside 180 s (#345)`. Rerun green. Log: `596-gates.log`.

`NoAutoCreateFixture` (`tests/Vonk.Api.IntegrationTests/TenantSchemaWithoutAutoCreateTests.cs`) boots the host with tenant auto-create off; `ManagedHostReadSurfaceTests` owned it at the time.

## Expected

`WebApplicationFactory.DisposeAsync()` on every `VonkApiFixture`-derived host returns within seconds; the class's cleanup is green.

## Tests (RED first)

This item has no RED test yet: the awaited call is not named, and the test that pins it is written once it is.

## Done when

- The awaited call is named, with the thread or task dump that names it, in this file's Evidence
- The fixture's dispose returns inside the bound on ten consecutive full gates
- The fix, if any, lives where the hang is (the fixture's Wolverine shutdown configuration or a Wolverine option), not in a longer bound
- event-sourcing-engineer reviews the Wolverine side
