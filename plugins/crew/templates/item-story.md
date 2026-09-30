<!-- Story body. Read at runtime by /crew:refine from the plugin. A project overrides the whole
     shape by placing its own copy at .claude/crew/items/story.md; that file then wins and stops
     receiving plugin improvements to this kind.
     Title is the project's commit format: <type>(<scope>): sentence. No internal codes.
     "## Tasks" MUST stay the last section: the tracker adapter appends its checklist there. -->

## TL;DR

<One or two sentences. Who gets what, in the words a customer would use. No type names, no file
paths, no item numbers, no "the platform" where "we" is plain. If it cannot be written without one,
the item is scoped wrong. Say so in the body instead.>

## Why it matters

<At most four lines: who is hurt today, what it costs them or us, what they can do afterwards that
they cannot do now. This section decides whether the work is worth doing. Nothing technical.>

## Today, in detail

<The current behaviour and why it is wrong, with the evidence: what was seen, where, at which
commit. The first sentence is the problem, never the provenance.>

Decision: <who, date, the sentence they settled>.

<This line repeats: one Decision: line per settled decision, in the order they were settled, never
merged into a paragraph and never summarised into one. A story carrying six or eight of them is normal;
a reader must be able to point at the line that settles the argument they are about to reopen. Do not
reopen a settled decision later in the body.>

## Acceptance criteria

<Numbered, Given/When/Then, grouped under bold subheadings when there are more than about eight.
Numbers are permanent: never renumbered, never reused. A withdrawn criterion stays in place reading
"withdrawn — <reason>". Each is observable by a user or an operator, and each is one outcome: if the
Then needs "and" between things that could fail independently, it is two criteria.>

**<Group>**

1. Given <state>, when <act>, then <the one observable outcome>.
   *Would be proved by: <what would show it — a witness, an observation, a named reader's judgement.
   The product owner writes this line and only the product owner edits it. It is what WOULD prove the
   criterion, written before anyone knows the test's name; it is never rewritten afterwards to match
   what the engineer did.>*
2. Given …

<Who names the proof, so the two can never disagree: the product owner names what WOULD prove each
criterion, on the italic line above; the engineer names the test that DID prove it, in the Proof map's
third column. They answer different questions — intent and record — so neither overrides the other.
A criterion whose italic line and whose Proof map row describe different things is not a contradiction
to resolve by editing one of them: it is a finding, and it goes to the product owner, who either accepts
the engineer's proof as sufficient or says which part of the criterion is still unproved.>

## Out of scope

- <thing a reader would otherwise assume is included, and where it lives instead>

## Proof map

<One row per criterion. The product owner ships this with only the first column filled; the
architect fills Task at plan time; the engineer fills "Proven by" in the PR that lands it — that column
is the engineer's alone, and it names the test that actually ran, never a restatement of the criterion's
own "Would be proved by" line; the lead ticks when that PR is merged and — where the project has a
deploy target — seen working there. This
table is the only place anyone looks to answer "how far is this story".
Where the tracker cannot render a table, this map lives in the story's design document under
<profile:designs> and this section links to it instead.>

| AC | Task | Proven by | ✓ |
|---|---|---|---|
| 1 | | | |
| 2 | | | |

## Open questions

1. **<the question>** — Recommendation: <answer, and the one reason>.

## Related

<Other items, designs, and the provenance of individual criteria if any needs it. Provenance lives
here once, never as a tag on every criterion.>

## Tasks
