# Pilot: three real items converted by hand, 2026-10-01

Evidence for `../backlog-as-data.md`, produced before any of story #45's eight tasks was built.
Three real `vonk-platform` items were converted into D21's one-file shape **by hand**, to find out
what the schema cannot hold. It found plenty; the findings are on claude-crew issue #45.

These files are kept for two reasons. They are the **worked examples the conform skill needs** — #51
turns `/crew:conform` into the importer, and the editorial judgements made here are the rules it has
to carry. And they are the only record of what a conversion actually looks like against bodies
nobody wrote with this design in mind.

| File | The real item | What it demonstrates |
|---|---|---|
| `724.md` | a typical task | the common case: one role, a story, a design with sections, eight declared paths |
| `591.md` | a bug | prose carrying **two bare ``` lines** and a stack trace, which the shape survives; two roles, which `role` cannot hold; three comments that revise the body's own diagnosis |
| `649.md` | a decision-record task | **no story, no design, proves nothing** — refused three times by the schema as written; a 13-column table under a non-template heading; provenance text that is lost when the table moves |

Each `<id>.rendered.md` is the tracker body a person would accept, written by hand beside its source,
so the round trip can be judged rather than assumed.

`variants/` holds the three deliberate breaks. Two are real defects, both one-line fixes belonging to
#46: `591-crlf.md` and `724-trailing-space.md` each make the extractor bleed the whole prose into
`jq`, because a `\r` or a trailing space defeats the "a line that is exactly three backticks" test.
`591-heading-in-fence.md` is the one that did **not** break it — a `## ` line inside a fence counts as
a heading only to a naive scanner, and no real body in either repository has one.

What the conversions could not carry, and which the importer must therefore ask a role about rather
than guess: a second or third owning role, a bug's `found`, facts that live only in comments (a
revised diagnosis, "needs a reseed on deploy", vonk's "deployed and seen working"), annotations on a
blocker, wave numbers, and design-internal task ids.

Do not treat these as fixtures for a test. They were written by judgement, against a schema that is
expected to change before #46 lands — `story`, `proves` and `design` are likely to become optional,
and the size contract to warn rather than refuse. Their value is as evidence of real shapes, not as
an expected output.
