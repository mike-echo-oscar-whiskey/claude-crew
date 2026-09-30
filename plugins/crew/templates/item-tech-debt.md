<!-- Tech-debt body. Read at runtime by the crew; override at .claude/crew/items/tech-debt.md.
     Title is the project's commit format. Severity is a p1/p2/p3 label, never the body.
     Add the index line the profile's architect binding names, if it names one. -->

Found in: <the item or review that found it> · pre-existing since <when, if known>

## TL;DR

<One or two sentences: what is wrong with the code or the setup, and what it will cost if nobody
touches it. Plain language — a reader who has never opened this repository understands the risk.>

## In one paragraph

<Where the debt is, what shape it takes, and why it was not fixed when it was found — usually
"it predates the task that found it".>

## Cost

<What it costs today: the bug it will cause, the work it slows, the surface it leaves unguarded.
Concrete, with the path and line where it bites.>

## Way out

<At most three lines, and no design: the direction, not the plan. The architect owns the plan, and a
detailed one written here goes stale before anyone reads it.>

## Trigger

<The event that turns this into a story: "the next change to X", "before the first paying customer",
"when the second caller appears". A debt item with no trigger is never picked up.>
