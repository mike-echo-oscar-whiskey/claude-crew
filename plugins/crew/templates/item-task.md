<!-- Task body. Read at runtime by /crew:plan from the plugin; override at
     .claude/crew/items/task.md.
     The "Story:" line MUST be the literal first line of the body, and the adapter writes it:
     tracker.sh rolls tasks up under their story with startswith("Story: #<n>") and greps
     ^Story: # for the claimable list. A task filed by hand, from a web-UI template, is
     invisible to the board without it. "Blocked by:", "Role:" and "Size:" must be present too,
     and an override changes neither requirement: it decides the sections, not these four lines. -->

Story: <profile:tracker-sigil><n>
Blocked by: <refs, or "none">
Role: `<crew role>` · design: `<profile:designs><slug>` <sections, or "none">
Size: <H> hand-written files (+ <G> generated) · <T> RED tests · one PR
Split line: <the seam this task is cut at if it grows past the cap (<profile:size-cap>) — which files and which criteria
            go to the follow-up. "n/a — the cap holds with room" is a valid answer. When the profile
            declares no size cap, Size is still counted. Replace this line with "Exception: <reason> —
            <H> files, no behaviour change; reviewed as one sweep." only for a mechanical sweep
            provable by a search that afterwards returns nothing, or a regenerated set that must land
            with its generator to keep the tree buildable.>

## TL;DR

<One or two sentences: what a person will be able to do, or see, that they cannot now — or, for an
internal step, what the next task can then do. No type names, no file paths.>

## In one paragraph

<The shape of the change in five or six sentences: what is added, what is renamed, what deliberately
does not change yet and which task does it. A reviewer reads this and nothing else before opening
the diff.>

## Goal

<The precise statement, in the codebase's own vocabulary: types, fields, contracts, error codes,
what stays on the wire, whether a generated client is regenerated, whether a data migration is
needed. This is the section that may name technology; everything above it may not.>

## Proves

- `<story-ref> AC <n>` — <the half of that criterion this task proves, when it is a half>

## Files

- `path` — <what changes there>

<H in the Size line is the length of this list. Files matching one of the profile's generated paths
are counted in G instead and do not spend the cap: nobody reviews them line by line.
Generated paths: <profile:generated>>

## Tests (RED first)

1. **RED** `<Test>` — <the behaviour, and the criterion it proves>

<At most five numbered RED tests. Six is a signal, eight is three tasks: the file list is a guess
made before opening the code and is routinely low, while the RED list is a decision and is
accurate.>

## Done when

- <only what is specific to this task: the search that must return nothing after a rename, the named
  reviewers beyond the project's default, the one thing to observe on the deploy target>

*Common definition of done: <profile:definition-of-done>, walked in the PR. Merged by <profile:merge-authority>.*
