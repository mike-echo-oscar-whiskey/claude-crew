<!-- Bug body. Read at runtime by the crew; override at .claude/crew/items/bug.md.
     Title is the project's commit format. No internal codes. -->

Role: `<crew role>` · design: <none, or the doc> · found <where and when>

## TL;DR

<One or two sentences: what a person sees going wrong, and what they should see instead. No type
names, no file paths.>

## In one paragraph

<What happens, what should happen, and why it happens — the mechanism, once the reader has the
symptom. Ends with what it has cost so far, in time or in trust.>

## Evidence

<The reproduction, verbatim, at a named commit: the commands and their output, or the two requests
that differ. Enough that a reader reproduces it without asking a question.>

## Expected

<The behaviour in one sentence, stated so a test can assert it.>

## Files

- `path` — <what changes there>

Size: <H> hand-written files (+ <G> generated) · one PR

## Tests (RED first)

1. **RED** <the test that fails on today's code>

## Done when

- The test is green and was red first, both runs quoted
- <the specific observation that proves it on the deploy target, when the bug is only visible there>
- <named reviewers beyond the project's default>

*Common definition of done: <profile:definition-of-done>, walked in the PR. Merged by <profile:merge-authority>.*
