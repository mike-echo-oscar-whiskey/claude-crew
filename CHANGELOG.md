# Changelog

Per release: what changed, what to do, and what happens to a project that changes nothing. Entries
are appended, never rewritten — an entry describes the release it names, not the current tree.

## 0.9.0 — 2026-10-02

**The release that conforms a story whole, checks what its bodies claim about the repository, and lets
`/crew:work` say in one line when that has not happened since the last edit.** A shape-only pass could
not have caught the lint-clean task body that asserted a demo seed listed only in-plan models when it
did not; it cost a blocked implementation run and three questions to the user. `/crew:conform` now takes
a story — a task number widens to its story and every task that story lists — and has one scout per item
verify every concrete claim about the repository before the diff is shown.

The payload moved in `plugins/crew/skills/conform/SKILL.md`, `plugins/crew/skills/work/SKILL.md` and
`plugins/crew/scripts/tracker.sh`; `tests/tracker.test.sh` and `tests/review-contract.test.sh` ride along.

### What changed

- **`/crew:conform <n>` conforms a story and all its tasks.** A task resolves to its story by its
  `Story:` line, else by the story whose `## Tasks` lists it; none or two is a question, never a guess.
  `--all`, a bug and a tech-debt item get the shape pass exactly as before.
- **A premise check, step 4.** One `crew:scout` run per item returns each claim the body makes about the
  repository as verified, contradicted, drift or unverifiable, each with path:line and the quoted line.
  A contradiction is shown in the diff as a question and never rewritten into the body; line drift alone
  may be corrected as a countable fix shown in the diff.
- **One marker per story.** After the approvals, and on a yes, the pass comments on the story with a first
  line `crew:conform <UTC ISO 8601> <short HEAD>` and lists what conformed, what was declined and what
  was left open.
- **`tracker.sh conformed <n>`**, read-only: exit 0 when the newest marker is newer than the last body
  edit of the story and of every task it lists, 1 when not, 2 when it cannot decide, one stdout line each.
  It reads GraphQL `lastEditedAt` (`createdAt` before a first edit), because `updatedAt` moves on every
  comment, label and close — the marker itself included.
- **`/crew:work` step 1** runs that lookup once and relays its line when the exit is 1 or 2, then carries
  on. It never blocks and never runs the pass.

### What to do

1. Install it: `claude plugin install crew@claude-crew`.
2. Nothing else is required. Run `/crew:conform #<story>` before working a story whose bodies were written
   against an older tree.

### What happens if a project changes nothing

1. **`/crew:work` prints one extra line** for every story not yet conformed — every story on a board that
   predates this release — and proceeds as before.
2. **`/crew:conform <task>` now touches the whole story**, where it used to touch only that task, and
   dispatches one scout per item in it.

## 0.8.3 — 2026-10-02

**The release that reads a `## Proves` bullet by how it opens, and gives a task that proves nothing a
declared way to say so.** The check asked whether the section contained `AC <n>` anywhere, so a bullet
that proved no criterion passed by naming the criteria it did not prove: a preparatory task whose one
bullet read "none of `#676 AC 1–12` — …" linted as conforming while saying the opposite. Every top-level
bullet now opens with its reference, `<sigil><n> AC <m>`, backticked or bare; a task that proves nothing
writes one bullet, `none` and a reason, the way `test-free` licenses `0 RED tests` and `Exception:`
licenses the size cap.

Patch, not minor, by the test the last six releases used: nothing new can be invoked, passed or filed.
`task create` and `lint`, which share the validator, refuse bodies the template already said were wrong —
its one example bullet opens with the reference — and the `none` form is accepted where the old check
accepted the same text by accident, so it is a reading of an existing body, not a new capability. On the
board this was cut against, `lint --all` reports the same items before and after.

The payload moved in `plugins/crew/scripts/tracker.sh` and `plugins/crew/templates/item-task.md`;
`tests/tracker.test.sh` rides along.

### What changed

- **A `## Proves` bullet is judged by its opening, not its mentions.** `check_proves` reads each
  top-level bullet: one that does not open with `<sigil><n> AC <m>` is refused as
  `refused: ## Proves bullet does not open with a criterion reference ("#<n> AC <m>"): <the bullet>`,
  one line per bullet. A section with no bullet at all is refused as naming no criterion.
- **`none` is the declared form for a task that proves no criterion.** It must be the section's only
  bullet and carry a reason; a bare `none` and a `none` beside a reference are each refused by name.
  `item-task.md` says so in one line under the example bullet.

### What to do

1. Install it: `claude plugin install crew@claude-crew`.
2. **Run `scripts/tracker.sh lint --all` once.** A task whose `## Proves` bullets mention a criterion in
   prose is reported now; rewrite each bullet to open with its reference, or, for a task that proves
   nothing, replace the list with `- none — <why>`.

### What happens if a project changes nothing

1. **`lint` may report a task it passed yesterday**, for a `## Proves` bullet that does not open with a
   reference, and the `/crew:status` conformance count moves by the same number.
2. **A `task create` that used to succeed can be refused** for the same shape, exit 1, nothing written.
   A body in the template's form is accepted as before.

## 0.8.2 — 2026-10-01

**The release that makes the placeholder scan a parser instead of a pair of regular expressions, and
tells a reviewer what the blocking severity is for.** `0.8.1` fixed the stub its scan could not see by
adding a third patch to a strip that paired backticks by regex from the left; this release retires the
strip. Pairing from the left meant prose with an odd number of backticks paired two characters that were
never a span and deleted everything between them — a stub included, which is the one thing the scan exists
to catch — and a fence indented inside a list item was not a fence at all, protected only by that same
accidental pairing until one stray backtick before it flipped the pairs. `body_placeholders` is now one
awk pass with explicit state: a fence is a line, a code span lives inside a paragraph, and nothing pairs
across a blank line. The other half is a sentence the five files that state the severity obligations did
not say: a mutation review always finds surviving mutants, and a check that cannot fail over code that is
correct harms nobody, so it is one severity down and never blocks.

Patch, not minor — and the lead deliberately left the number open this time, so the test is run against
both halves. The test the last five releases used: a minor is a capability a consumer can now exercise
that it could not — invoke, pass, file under, have fired — and `0.8.0` added that an existing command
producing output it could not produce before counts when the documents had expressly said it would not.
#42 reaches the five commands that share the scan — `story create`, `task create`, `bug create`,
`tech-debt create` and `lint` — and every one keeps the contract every document states: an unfilled
template stub is refused, a fence quotes anything. Three bodies they accepted are refused and one they
refused is accepted, and in each case the document was already on the new side. `0.8.1` wrote "a fence
now quotes anything, stub included" and shipped a fence rule that held only at column 0; it wrote that a
span holding nothing but a stub is a stub and unwrapped exactly one token, leaving `item-task.md`'s own
design line — two tokens side by side — as the second stub the scan could never report; and no release
ever wrote that two stray backticks switch the scan off between them. #43 reaches the review step, the
work step and three personas, which already said that a finding carries its reproduction, that severity
is anchored to what a second reader can check and not to taste, and that a reviewer may depart from the
anchor with the one reason stated. This release says what the anchor's blocking rating is *for*, names one
departure as the rule rather than the reviewer's call, and makes the downgrade carry the evidence the
finding already had to. Nothing new can be invoked, passed or filed; no label, hook, template, profile key
or item section moves; and the obligation that moves is the one `0.8.1` shipped as a patch under #40,
calibrated.

The case for a minor is real and worth stating, and it is stronger than `0.8.1`'s was. The reach is
wider: three refusals and one acceptance where `0.8.1` carried one of each, over the same five commands,
so an existing board holds more bodies `lint` now reports differently. And `0.8.1`'s own argument turned
on "the contract the number guards has not moved, only the code that was short of it" — for a persona or
a skill there is no code apart from the document, so when the review step moves, the contract moves with
it, and a consumer whose reviewers are agents receives a verdict yesterday's reviewers were told not to
give. Neither survives the question the test asks. Reach was ruled on in `0.8.1`: a patch that may never
move a `lint` verdict would make every scan correction a minor, and the number would stop saying whether
there is anything new to learn. And the verdict was producible yesterday: the departure clause already let
a reviewer rate a survived mutant on a touched line below the anchor with its reason, and the lead already
accepted or contested it; what moved is that the departure stopped being discretionary for one named
case, and that the obligation of evidence now runs both ways. A minor would tell an upgrader there is
something new to do, and there is not — there is a rule to read, which this entry states, and a `lint`
run to make.

The payload moved by all four commits. `c39f762` and `ec352d0` change `plugins/crew/scripts/tracker.sh`;
`56ee153` changes `plugins/crew/skills/review/SKILL.md`, `plugins/crew/skills/work/SKILL.md`,
`plugins/crew/agents/architect.md`, `plugins/crew/agents/qa-engineer.md` and
`plugins/crew/agents/security-engineer.md`; `1495230` changes the same three personas again. The
`docs/design/item-data.md` half of `c39f762` and the `tests/` halves of all four earn nothing by this
repository's rule and ride along.

### What changed

- **A paragraph bounds a code span, so a stray backtick is literal text** (#42). `0.8.1` paired backticks
  from the left across the whole body, so a body with a filled role, a lone backtick, a stub and a second
  lone backtick was accepted silently: the two lone backticks paired as a span and the stub between them
  was stripped as its content. The scan now reads one paragraph at a time — lines joined, because a span
  and a stub both wrap across a line break, and joined no further than the next blank line, because a
  code span cannot cross one. Inside a paragraph a run of n backticks opens a span only when a run of
  exactly n closes it later; an unclosed run is literal. A lone backtick therefore has no closer in its
  own paragraph, is text, and the stubs after it are read and refused as
  `refused: unfilled template placeholder — <token>`, from every one of the five commands. What stays,
  because it is CommonMark's own rule: within a single paragraph a stray backtick still pairs with a later
  run of its own length.
- **A span holding nothing but stubs is unwrapped, however many** (#42). `0.8.1` unwrapped a span whose
  entire content was one `<…>` token, which reached `item-bug.md`'s `` `<crew role>` `` and not
  `item-task.md`'s `` `<profile:designs><slug>` ``. A span whose content is nothing but `<…>` tokens is now
  unwrapped before the strip, so a task whose design line is still the template's stub is refused, one
  line per token: `refused: unfilled template placeholder — <profile:designs>` and the same for `<slug>`.
  `` `<div> plus prose` `` is still prose, and `List<string>` is still a type.
- **A fence is recognised indented up to three spaces, and no further** (#42; the bound is `ec352d0`). A
  fence inside a list item is now a fence, so a stub quoted there is safe whatever backticks precede it —
  under `0.8.1` an indented opener was not matched, its three backticks went to the span strip, and one
  lone backtick earlier in the body exposed the quoted stub and refused the body; that is the one body
  this release accepts that `0.8.1` refused. The bound stops where CommonMark stops: at four spaces a line
  is an indented code block and its backticks are content, and while the opener accepted any indent two
  markers four spaces deep paired as a fence and swallowed a stub between them — the same silent
  acceptance as the stray backticks, through the door the bound closes. A tab matches no space, so a
  tab-indented marker is not a fence. The rest of the fence rule holds: nothing between an opener and its
  closer is read, and an opener with no closer protects nothing.
- **The cost, unchanged in kind and slightly wider in reach: a bare backticked `<token>` in prose is
  refused, and now two of them side by side too.** `0.8.1` named the single token; the unwrap above makes
  `` `<a><b>` `` indistinguishable from a shipped stub as well. A body that means the literal tokens
  writes them in a fence, where nothing is read, or puts any other word beside them in the span.
- **One portability assumption, recorded in prose because this file has no heading for one.** The fence
  bound is an ERE interval expression inside awk — `/^ {0,3}```/` — the first in these scripts. POSIX
  requires intervals and every mawk since 1.3.4 has them; gawk, which this release was cut and gated on,
  has them. On an awk without them the opener never matches, so no fence is recognised and a stub quoted
  inside one is read as prose and refused — a false refusal, never a silent acceptance. In this repository
  such an awk fails three fence witnesses on the first gate run rather than misbehaving quietly.
- **A check that cannot fail over correct code is one severity down and never blocks** (#43). A mutation
  review of the placeholder scan found five surviving mutants, every one on code that was correct, and two
  rated at the blocking severity sent a finished change back; a mutation review always finds survivors, so
  a rule that blocks on them is a rule under which nothing ships. The five files that state the severity
  obligations — the review step, the work step, and the architect, qa-engineer and security-engineer
  personas — now bound what may block by what the blocking rating is for: harm a person can meet —
  behaviour that is wrong, a silent acceptance where a refusal was owed, data lost. A check that cannot
  fail for the reason it was written, on code that is correct, is one severity below the anchor's rating
  and never sends the change back; it is fixed in the same change when that change wrote the check, and
  becomes its own tracker item when the check was already there. Each file says it in its own register —
  the qa-engineer persona, which the rule binds hardest, as the departure its mutation anchor already
  allows — and the three existing obligations keep their wording: no word was deleted from any shipped
  file.
- **The downgrade carries its own evidence** (#43, `1495230`). Every finding owed a reproduction while the
  downgrade that stops a finding blocking owed none, and "the code is correct", asserted and not shown, is
  an escape hatch out of the three obligations rather than a judgement a second reader can check. The
  qa-engineer persona now requires, with the downgrade, the production line quoted or the command whose
  output shows the behaviour is right. Two personas that rated the downgrade a flat `p2` where the others
  said one below the anchor now say one below the anchor too, so a mutant in a file the change touched
  gets the same answer from every file.

### What to do

1. Install it: `claude plugin install crew@claude-crew`.
2. **Run `scripts/tracker.sh lint --all` once.** Three shapes of body passed under `0.8.1` and are
   reported now: a stub standing between two stray backticks in one paragraph; a task whose design line
   still reads `` `<profile:designs><slug>` `` — filed under any release up to `0.8.1`, it is the second
   stub no scan could see; and a stub between two code-fence markers indented four spaces or more. One
   shape is the reverse: a body `0.8.1` refused for a stub quoted inside an indented fence passes now and
   needs nothing. Edit a reported body so the stub names its value; nothing else about the item needs to
   move.
3. **A new body that wants a literal `<token>` — or two side by side — puts them in a fence**, or beside
   another word in the span; `0.8.1`'s route is unchanged and now covers the pair.
4. **Read the calibration once if your reviewers are agents.** A `Survived` mutant on a line the change
   touched is still `p1` by the anchor; a reviewer who finds the production code correct and the test
   unable to fail now rates it one below, says so as the departure, and quotes the line or the command that
   shows the code is right, and the lead does not send the change back for it. Nothing to re-render and
   nothing for `--refresh` to offer: no template, profile key, label, hook or item section moved.
5. **Check your awk only if it is neither gawk nor a mawk from 1.3.4 on.** Run any create against a body
   that quotes a stub inside a fence: a refusal where `0.8.1` accepted it means the interval expression
   is missing, and the fix is an awk that has it.

### What happens if a project changes nothing

1. **`lint` may report an item it passed yesterday, for the three shapes above, and may pass one it
   refused.** Each is the rule every release published — an unfilled stub is refused, a fence quotes
   anything — now held; the `/crew:status` count of items still matching the item shape, which comes from
   `lint --all --quiet`, moves by the same number.
2. **Two creates that used to succeed can be refused**: a body with a stub between two stray backticks in
   one paragraph, and a body with a span holding nothing but `<…>` tokens, `item-task.md`'s design line
   left as shipped included. Both answer `refused: unfilled template placeholder — <token>`, exit 1, and
   create nothing, as every refusal does. One create that used to be refused succeeds: a stub quoted in a
   fence inside a list item.
3. **A review that would have blocked may not.** A reviewer reading the installed personas rates a
   toothless check over correct code one severity down, with its evidence, and the work step does not send
   the change back for it. No command's output or exit code moves for it.
4. **Everything else is identical.** No label, hook, item section, profile key or template changes, and
   `--refresh` on any profile behaves exactly as it did under `0.8.1`.

## 0.8.1 — 2026-10-01

**The release that keeps a promise `0.7.0` published and did not keep.** `0.7.0` said the placeholder
scan "already refuses" a bug whose role line is still the template's stub, and offered that sentence as
one of the three reasons `bug create` takes no `--role` flag. It was false when published: `item-bug.md`
writes `` Role: `<crew role>` `` inside a code span, and the scan stripped every code span before it looked
for stubs, so of the sixteen stubs in that template the one naming an owner was the one it could never
report. A bug could be filed with nobody owning it, and `lint` said nothing. This release makes the
sentence true, and the correction `f6b898d` placed under the `0.7.0` entry now names this release instead
of "after `0.8.0`". The other half of this release is a sentence the review and work steps owed story #2
for three releases: a change is not recorded as reviewed until the named human has read it, and merge
authority is not that reading.

Patch, not minor — and the lead said patch first, which is the opposite of how `0.8.0` went, so the test
is run again here rather than inherited. The test the last four releases used: a minor is a capability a
consumer can now exercise that it could not — invoke, pass, file under, have fired — and `0.8.0` added
that an existing command producing output it could not produce before counts when the documents had
expressly said it would not. Here every document said the opposite. `0.7.0` promised the refusal, the
scan fell short of it, and now it delivers it; nothing new can be invoked, passed or filed, and the
contract the number guards has not moved, only the code that was short of it. The patch number tells an
upgrader exactly that — the same rules, now enforced — where a minor would say there is something new
to learn, and there is not.

The case for a minor is real and worth stating. `f6b898d` changes what five existing commands answer:
`story create`, `task create`, `bug create`, `tech-debt create` and `lint` all reach the same scan, and
three of its answers move. A body `0.8.0` accepted is now refused (the span-wrapped stub); a body `0.8.0`
could refuse by accident is now accepted (a stub quoted inside a fenced block); and a body carrying a
backticked `<token>` standing alone in prose — `` `<div>` `` — is now refused as a stub, which it was not.
That is more surprise than `0.7.2` carried. It does not survive the question of which of the three any
document promised. The first is the kept promise. The second was written nowhere as a refusal, so no
reader has an instruction to unlearn — it is a defect that stopped. The third is the one genuine
narrowing, and it was promised neither way: `0.8.0`'s acceptance of it was a side effect of the same
strip that hid the role stub, not a rule anyone could cite, and a body that hits it has a one-line route
around it. Ruling that a patch may never move a `lint` verdict on an existing board would make every
scan correction a minor, and the number would stop saying whether there is anything new to learn.

The payload moved by two commits. `e7c5862` changes `plugins/crew/skills/review/SKILL.md` and
`plugins/crew/skills/work/SKILL.md`; `f6b898d` changes `plugins/crew/scripts/tracker.sh`. The other four
— `b4902e0`, `f352542` and `d6bfdfc` in `docs/design/`, `0bc1571` in `tests/` — and the README, test
and changelog halves of the two above earn nothing by this repository's rule and ride along.

### What changed

- **A span holding nothing but a stub is a stub** (#41). `body_placeholders` strips code spans so that
  a wrapped `` `<…>` `` and a real `List<string>` are not reported, and it kept doing that while
  `item-bug.md` shipped its role as `` `<crew role>` `` — the one stub the strip removed before the scan
  could see it. A span whose entire content is one `<…>` token is now unwrapped before the strip, and
  only that: `` `<div> plus prose` `` is still prose, and `List<string>` is still a type. The refusal reads
  `refused: unfilled template placeholder — <crew role>`, and because every kind's validator calls the
  same scan, it comes from `story create`, `task create`, `bug create`, `tech-debt create` and `lint`
  alike. The witness is "bug create refuses a body whose role line is still the template's stub", and
  `plain_create`'s comment now says the no-`--role` reason holds only through this unwrap.
- **A fenced block is read for nothing** (#41). Fences are dropped whole, line by line, before the span
  strip runs. Under `0.8.0` a fence protected its contents only by accident: its three backticks were
  fed to the span strip, where two cancelled and the third paired with the next backtick in the text, so
  one stray backtick anywhere before the fence flipped the pairing and exposed the very lines the fence
  was quoting — a bug report quoting a template stub verbatim could be refused for containing it. A
  fence now quotes anything, stub included. An opener with no closer protects nothing: its lines are
  handed back to the scan rather than dropped, so a single stray fence cannot switch the rest of the
  body's scan off.
- **The one new refusal: a bare backticked `<token>` in prose.** This is the cost of the first item.
  `` `<div>` ``, `` `<T>` ``, any span that is exactly one angle-bracket token, is indistinguishable from a
  shipped stub and is now refused as one. A body that means the literal token writes it inside a fence,
  where nothing is read, or puts any other word beside it in the span.
- **A change is not recorded as reviewed until the named human has read it** (#40). Story #2's third
  criterion had two halves; the ceiling half (one round of agent review, a contested finding to the
  user, the agent review a net under the human's) was stated and held by witnesses, and the *then* half
  was in no sentence the plugin shipped. The review step now ends step 3 with it: that ceiling bounds
  the agents, not the review, so what the lead posts in step 4 is evidence for the named human and
  never the record that the change was reviewed. The work step reconciles step 7 with it:
  `merge-authority:` answers who may merge and says nothing about who has read, so a lead merge
  finishes the item and leaves the reading owed, the report says which of the two happened, and where
  the named human merges the reading and the merge are one act. Neither state holds a merge — `done`
  records the work, not the reading. The README's "Honest limits" says the same in the second person,
  and the review-contract witness holds all three places plus the *believed* marking in the five files
  that file or receive findings (53 → 62 cases).

### What to do

1. Install it: `claude plugin install crew@claude-crew`.
2. **Run `scripts/tracker.sh lint --all` once.** A bug filed under `0.7.0`, `0.7.1`, `0.7.2` or `0.8.0`
   with its role line still reading `` `<crew role>` `` passed every check then and is reported now, with
   the line above. Edit that body so the role line names the role; nothing else about the item needs to
   move. The same run names any body that carries a bare backticked `<token>` in prose.
3. **A new body that wants a literal `<token>` puts it in a fence**, or beside another word in the span.
   A template stub quoted verbatim — in a bug about the templates, say — goes in a fence too, and is
   now safe there whatever backticks precede it.
4. **Nothing to re-render and nothing for `--refresh` to offer.** No template, profile key, label, hook or
   item section moved. The review and work steps read differently; the obligation they add is on the
   named human and changes no command.

### What happens if a project changes nothing

1. **`lint` may report an item it passed yesterday.** That item was defective under the rule `0.7.0`
   published — a bug nobody owns — and the report is the fix working. The `/crew:status` count of items
   still matching the item shape, which comes from `lint --all --quiet`, moves by the same number.
2. **One create that used to succeed can be refused**: a body with a span that is exactly one
   angle-bracket token answers `refused: unfilled template placeholder — <token>`, exit 1, and creates
   nothing, as every refusal does. The fence route needs no upgrade knowledge beyond this entry.
3. **Everything else is identical.** No other command's output or exit code moves, no label, hook, item
   section, profile key or template changes, and `--refresh` on any profile behaves exactly as it did
   under `0.8.0`.

## 0.8.0 — 2026-10-01

**The first release an already-configured project can receive a standard from.** Every release before
this one could only reach a profile at `/crew:init` time. The profile is rendered once and then belongs
to the project, and `--refresh` "keeps the user's hand edits and only updates scanned lines" — languages,
commands, folders, the tracker. `0.7.2`'s entry had to turn that into an instruction: a project that
wanted the new release rule was told to paste the bullet into its own Definition of done by hand,
because "no upgrade will deliver it". This is the release that delivers it — and the next template key,
and the one after that.

Minor, not patch, and the call was close enough that the lead said 0.7.3 first. The test the last three
releases used is that a capability is something a consumer can now *do* that it could not: invoke, pass,
file under, have fired. `0.7.2` turned on exactly that distinction when it refused a minor for a shipped
template bullet — that bullet was something the crew is *measured against*, and any project could already
have written it into its own profile by hand. This release is the other side of that same line. Receiving
a new profile key or a new definition-of-done item into an existing profile was not merely awkward to do
by hand; **no command did it at all**, which is the whole of what #36 was filed as. And two commands that
already existed now produce output they could not produce before: `/crew:init --refresh` asks questions
and can write into a section it was documented never to touch, and `/crew:status` prints a line naming
drift it never measured. Both `0.7.0` and `0.7.2` named "no command that already existed changes its
output or its exit code" as part of why their number was what it was. Here that sentence is false, and
it is false in the direction of more capability.

The case for a patch is real and worth stating: the flag already existed, no new command, flag or file
appears, and `--refresh`'s purpose was already to bring a profile up to date, so this could be read as a
promise kept rather than a surface added. It does not survive the documents. The promise was expressly
*not* made — step 8 scoped `--refresh` to scanned lines, and `0.7.2` used that exact wording as proof
that the bullet could never arrive. Reading this as a patch would have cost two things. A project that
read `0.7.2` was told to act by hand and that no upgrade would help it, so the version number is the
only signal that the instruction is now obsolete — and the entire value of this release depends on
somebody deciding the upgrade is worth running `--refresh` for. And the precedent: if widening a
documented flag from one compared set to three, with new prompts and new writes, is a patch, then only a
new command *name* could ever be a minor again, and `0.7.0`'s own bounding sentence about an existing
command's output would be naming a distinction that never decides anything.

The payload moved by one commit. `c3e8997` changes `plugins/crew/skills/init/SKILL.md` and
`plugins/crew/skills/status/SKILL.md`; `fd8d6ad` is a `docs/design/` file, which by this repository's
own release rule earns nothing.

### What changed

- **`/crew:init --refresh` offers what the installed template has and this project's profile lacks —
  one at a time, as a diff, written only on a yes** (#36). Two sets are compared and nothing else is.
  **Profile keys, by key name**: the template's top matter (`mode:`, `tracker:`, `default-branch:`,
  `branch-pattern:`, `designs:`, `generated:`, `size-cap:`, `definition-of-done:`, `merge-authority:`)
  against the keys the profile declares. `crew_profile_value` reads a key as `^<key>:` and nothing else,
  so the set of names on each side is the whole comparison; a key lacks when there is no such line at
  all, or when the line still carries the template's `<…>` placeholder, which every consumer reads as
  that literal string instead of the absent-key fallback. Values are never compared, and a key the
  profile has and the template does not is the project's own and is never mentioned — so rewording a
  value, a comment, a role line or a whole section, or reordering the file, produces no noise.
  **Definition-of-done items, by the rule each one states**: the project's list is resolved the way a
  task body resolves it (the path or section name `definition-of-done:` gives, else the profile's own
  section), and a template bullet is offered only when no bullet in that list speaks to its rule in any
  words. A bullet that says it differently, more strictly, or as a deliberate exclusion ("this project
  ships nothing, so no release is ever owed") states it and is not offered, because a project is
  expected to reword and a textual diff would offer every bullet on every refresh. Where the resolved
  list is a file other than the profile, the rule goes only into that file, never into both. Each offer
  stands alone: what it is, the installed version it comes from, a unified diff of the one file it would
  change, and then a stop. There is no batch yes, a no leaves the file exactly as it stands, and the
  step only ever inserts — it never rewrites a line, reorders a section or removes anything, so a hand
  edit cannot be overwritten by it. A non-interactive run — piped or empty stdin, a dispatch into a
  subagent — prints the diffs it would have shown, says that nothing was written, and offers none of
  them: **no answer is not an answer.** What this reaches first is the gap it was filed for: a project
  set up before `0.6.0` declares none of the four item-shape keys and silently takes every fallback, and
  a project set up before `0.7.2` has a definition of done that says nothing about releases.
- **Nothing records a decline, so a declined offer comes back at the next refresh** (#36). There is no
  ledger, and the step says so in the offer rather than pretending otherwise: it cannot tell a
  deliberate deletion from an item that was simply never offered, so it offers again. Running
  `--refresh` is therefore not a one-shot you can miss, and declining is not a decision that sticks.
  The way to make a deletion stick is to write the refusal into the project's own list as one line of
  deliberate exclusion, which the rule-level comparison above then honours; the way to stop a key being
  offered is to declare it with the value the project wants, including the literal `-` where the
  template documents one.
- **`/crew:status` gains a keys-only drift line** (#36). When the profile lacks a key the installed
  template has, one line appears under the board: `profile keys: <key>, <key> are in the installed
  template and not in this profile (/crew:init --refresh offers them)`. It names the keys and never
  their values, counts a surviving `<…>` placeholder as lacking for the same reason step 5 does, and
  says nothing when no key is missing or when there is no profile. The definition-of-done half of the
  same drift is deliberately **not** checked here: whether a project's list already states a shipped
  rule in its own words is a judgement, and a status run makes none.

### What to do

1. Install it: `claude plugin install crew@claude-crew`.
2. **Installing alone delivers nothing to an existing profile.** An install replaces the payload under
   `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/` and writes no file inside your project.
   In the whole payload the only thing that writes `.claude/crew/profile.md` is the `init` skill — step 4
   on a first run, and now step 5 on `--refresh`; every other skill, script and persona only reads it.
   The one thing the upgrade does give you unasked is the `/crew:status` line above, which *names* the
   missing keys without touching anything. Note how this differs from `0.7.2`, whose entry had to say
   that the shipped bullet reached new projects only: that release had no mechanism and said so; this
   one has one, and it is still opt-in.
3. **Run `/crew:init --refresh` to receive anything, and answer the offers.** Nothing is written without
   a yes, one offer at a time, each shown as a diff of the single file it would change. Decline freely:
   a no changes nothing, and the same offer returns at your next refresh.
4. **A project set up after this install needs nothing further.** `/crew:init` renders the current
   template, so every key and every definition-of-done item is already there.

### What happens if a project changes nothing

1. **Its profile stays exactly as it is.** Keys it does not declare keep taking their stated fallbacks —
   `size-cap: 15`, `definition-of-done:` resolving to the profile's own section, `merge-authority:` the
   author, `generated:` nothing excluded — and its definition of done keeps saying whatever it says
   today. Nothing refuses a PR over any of it.
2. **`/crew:status` says one more line than it used to**, naming the keys the installed template has and
   the profile does not. That line is the only visible consequence of upgrading and not refreshing.
3. **Everything else is identical.** No other command's output or exit code moves, no label, hook, item
   section or script changes, and `--refresh` on a profile that lacks nothing behaves exactly as it did
   before: scanned lines updated, hand edits kept, no offers made.

## 0.7.2 — 2026-10-01

**The first release this project owed rather than chose.** Six releases in, every number before this
one came from the lead's judgement; three of the five were judgement alone, two of those stranded
shipped work past a tag and one was nearly cut for commits no consumer could receive. `2e39c7f` wrote
the sentence that decides it, and the sentence then decided its own release: it changed
`plugins/crew/templates/profile.md`, that directory is the payload an install copies, so a release is
owed. Nothing here was weighed.

Patch, not minor. Nothing is added that a project can run: no command, no flag, no profile key, no
label, no item section, no hook, and no existing behaviour changes its output or its exit code. The
one case for a minor is real and worth stating — a project running `/crew:init` after this install
renders a definition-of-done item it would not have rendered before — and it does not survive the
question of what capability means. A capability is something a consumer can now do that it could not
do before: invoke, pass, file under, have fired. This bullet is something the crew is now *measured
against*, and any project could already have written it into its own profile by hand, because the
template's Definition of done is a list a project edits rather than a surface it calls. **Added
guidance is not added capability** — and this repository has twice decided in that direction already:
`0.7.0` was a minor because two tracker commands and two labels were new, and said so while expressly
setting aside "a rule the lead reads, a template sentence and thirty-four witness cases" as not what
decided it, which is the whole of this release; `0.6.1` was a patch by the same test. Calling this one
a minor would make every future wording improvement to a shipped template a minor, and the number
would stop carrying information.

Master moved by one commit and so did the payload — but not by the same amount of file. Of the three
files `2e39c7f` touched, one is shipped. `.claude/crew/profile.md` is this repository's own crew
configuration and `tests/review-contract.test.sh` is its own gate; neither is in an install, and by
the rule this release carries, neither would have earned one.

### What changed

- **The shipped profile template's definition of done says when a release is owed** (#33). Before
  this, `templates/profile.md` said nothing about versions, releases or tags: a project rendering its
  profile got "gates green, exit code quoted", the RED-before-GREEN line and one project-specific
  slot, and no statement of when a version has to move. The new bullet states the rule generally,
  because a consuming project may ship a library, a container image, a set of paths or nothing at all
  — a release is owed when what this project ships, which the rendered line names in place of the
  placeholder `<the published package, image, paths, or "nothing">`, has changed since the last
  released version, and the version is then bumped identically everywhere it is declared; a change
  confined to what the repository keeps for itself (its own agent rules and profile, developer
  scripts, tests, CI) earns none; a project that ships nothing never owes one; and cutting the release
  is the last step of finishing that batch rather than something remembered afterwards, because
  skipping it strands shipped work behind the last version and cutting one for repo-local changes
  claims a move no consumer can receive. Three assertions in this repository's
  `tests/review-contract.test.sh` hold those three sentences, so the bullet cannot later be softened
  back into a judgement call — they are this repository's gates, and nothing is asked of your
  project's tests.

### What to do

1. Install it: `claude plugin install crew@claude-crew`.
2. **A project set up before this release does not get the bullet, and no upgrade will deliver it.**
   A rendered `.claude/crew/profile.md` is the project's own file: `/crew:init` writes it once and the
   project hand-edits it afterwards. `--refresh` "keeps the user's hand edits and only updates scanned
   lines" (step 8 of the `init` skill), and the Definition of done is not a scanned line — step 1
   scans the repository for languages, commands, folders and the tracker, while the
   definition-of-done items are *asked* in step 3 and written once in step 4. Nothing in the plugin
   re-renders that section, and `/crew:status`'s only rendered-versus-installed check is a string
   compare of the `.github/ISSUE_TEMPLATE/` headers, which says nothing about the profile. So a
   project that wants the rule adds it itself: paste the bullet into its profile's Definition of done
   and replace the placeholder with what that project actually ships, or `nothing` if it ships
   nothing. One edit, no tooling.
3. **A project set up after this install gets it from `/crew:init`**, with the placeholder filled
   during setup like every other value, and has nothing further to do.

### What happens if a project changes nothing

Two things, and nothing else:

1. **Its definition of done keeps saying nothing about releases**, and its lead keeps deciding when a
   version moves on judgement — which is exactly what produced the three incidents this bullet
   exists to prevent, in this repository, within one day. Nothing refuses a PR over it: the item is
   guidance the lead walks, not a check a gate runs.
2. **Everything else is identical.** No command, flag, output or exit code changes; the installed
   payload gains and loses nothing but the one bullet in one template.

This release delivers a sentence to projects not yet set up. For every project already running the
crew it is a no-op that the lead has to act on by hand, and this entry says so rather than letting
"install it" imply otherwise.

## 0.7.1 — 2026-10-01

Patch, not minor: nothing is added, and no command, flag, profile key, label or item section is new.
`next` parses a field it already parsed, `/crew:init` does two things it already said it did, and four
witnesses leave a payload that never ran them. The one change that could be read as minor is that
move, because it changes what an install *contains* — and an install did contain them:
`~/.claude/plugins/cache/claude-crew/crew/0.5.9/scripts/tests/` holds all four, so the removal is
visible to anyone who looks, and this entry says so rather than calling it invisible. It is a patch
anyway, and for a reason stronger than size. That path carries the version in it, so no consumer ever
had a stable path to those files; nothing in the payload — no skill, hook or script — named or invoked
one; and two of the four could only exit 1 from inside an install, because they read a repository-root
README that an install has no copy of. The one instruction that ever pointed at them was `0.7.0`'s
Layout block, which listed them under `plugins/crew/` with "run bare" beside them — and following it
was already a failure for half of them. Nothing a project could have depended on is gone, which is
what decides the number.

Two of the five commits behind this release reached no consumer at all. `438cb51` and `cefd090` change
`.claude/crew/`, this repository's own crew configuration, which is not in the payload — so master
moved by five and an install moves by three. Counting all five is how an empty release came within a
command of being tagged earlier today; keeping the two counts apart is the subject of open item #33.

### What changed

- **`next` reads a task's story from the body's first line only, so a task that names its story twice
  prints one row** (#30). The story number came out of an unanchored `grep -oE '^Story: #[0-9]+'`, so
  every matching line in a body contributed one number. A task carrying `Story: #676` as its first
  line and `Story: #676 · design …` on its third yielded two, handed the row's `printf` an argument
  too many, and split the record across two lines — live on a 489-item board, where two tasks each
  printed as two half-rows. The anchored first-line parse `lint` has had since it was written is now
  the function `story_of_body`, and both call sites read through it: one regex in two places is how
  this bug existed, and it is the third of that shape. A first line that is not a story reference
  still contributes nothing and the row still prints, as `#?`.
- **The four witnesses leave the payload, so no install carries a test that cannot pass** (#31).
  `review-contract.test.sh` read `../../README.md` and `model-roster.test.sh` read
  `$crew/../../README.md`. An install is `{agents,.claude-plugin,hooks,scripts,skills,templates}`
  copied out of `plugins/crew/`, so a repository-root file is never two levels up and both exited 1
  on a consumer's machine; they passed here only because a checkout happens to put a repo root in the
  right place. Making the two skip on a missing file would have left the payload carrying tests that
  pass by asserting nothing, so all four move to `tests/` at the repository root instead, where each
  anchors on `$here/..` and derives `plugins/crew` from it. They are this repository's own gates:
  they are on the `test:` and `gates:` lines of **this repository's** `.claude/crew/profile.md`, and
  nothing is asked of your profile. `CHANGELOG.md` and the three `docs/design/` files naming the old
  path keep it, because they record what was true when they were written.
- **`/crew:init`'s two steps whose unhappy path was silence now have one, and say what they did**
  (#32). Step 7 appended a "Crew" section to `CLAUDE.md` when that file lacked one, so a project with
  no `CLAUDE.md` at all fell outside the condition and got no crew pointer without a word — in the
  one procedure a project runs once and never revisits. It now writes the file, holding one line of
  what the project is plus that same section, and reports creating rather than appending, so a user
  who did not want one can delete it. Step 4 now creates the directory the profile's `designs:` line
  names, because `/crew:plan` writes a design into it as its first act and a missing path surfaced
  there as a failed write, a pipeline away from the one `mkdir` that prevents it. It is created
  empty. Three values stay uncreated and are reported instead of attempted — a path outside the
  project, an absolute path, and no value at all — each with the value read and the sentence that
  `/crew:plan` will fail until the line is fixed.

### What to do

1. Install it: `claude plugin install crew@claude-crew`.
2. **Nothing is required.** `0.7.0` needed `ensure-labels` run before `tech-debt create` had a label
   to file under; nothing here gains a dependency on an action. The `next` fix is live the moment the
   install lands, no witness was ever on a path you used, and the `init` text is read the next time
   `/crew:init` runs.
3. Two optional repairs, both only for a project that already ran `/crew:init` and neither caused by
   this release — `0.7.1` is what makes them visible. If `.claude/crew/profile.md` names a `designs:`
   directory that is not there, `/crew:plan` still fails on its first write: `/crew:init --refresh`
   creates it, and so does one `mkdir`. If that project had no `CLAUDE.md` when it was set up, it
   still has no crew pointer and every future session starts without knowing the crew exists;
   `--refresh` writes the file. A project whose designs directory exists and whose `CLAUDE.md`
   carries a "Crew" section has nothing to do.

### What happens if a project changes nothing

Three things, and nothing else:

1. **`/crew:next` keeps printing a broken row** for any task whose body names its story on more than
   one line — two half-rows instead of one record, with the second carrying the overflow argument.
   Nothing else in the pipeline misreads it: `lint` always had the anchored parse, and a claim, a
   status rollup and a plan all read the first line.
2. **`/crew:init` keeps both silences.** A project set up without a `CLAUDE.md` is already past that
   step and cannot get the pointer back from an upgrade, and a missing `designs:` directory still
   surfaces inside `/crew:plan` as a failed write rather than at setup.
3. **Four files disappear from the installed payload** at `scripts/tests/`, and nothing else in it
   moves. No skill, hook or script referenced them, the path they lived on was stamped with the
   plugin version, and the two that read the repository README could only fail there. Everything
   that existed under `0.7.0` keeps its flags, its output and its exit codes, `lint`'s 2 among them.

There is no migration tooling, no version negotiation and no compatibility matrix.

## 0.7.0 — 2026-10-01

Minor, not patch: `tracker.sh bug create` and `tracker.sh tech-debt create` are commands that did not
exist, and `ensure-labels` mints two labels it did not mint. The rest of the release is a rule the
lead reads, a template sentence and thirty-four witness cases — but capability was added, and that is
what decides the number, by the same rule `0.6.1` used to decide it was a patch. No command that
already existed changes its flags, its output or its exit codes. One action is required of an
upgrading project, and unlike `0.6.1`'s it is not optional: `ensure-labels` is where the two new
labels come from, and `tech-debt create` has nothing to file under until it has run.

### What changed

- **`bug create` and `tech-debt create` file through the adapter, so the validator written for them is
  finally reached** (#21). The dispatch had arms for `story create` and `task create` and none for the
  other two kinds `lint` already judges, so `tracker.sh bug create …` fell through to the usage block
  — exit 1, no check named, nothing created — and whoever needed one of those items reached for `gh
  issue create`, where nothing looks at the body. `validate_plain_body` was written for exactly these
  two kinds and nothing called it. Both arms take `--title` and `--body-file`, validate the body before
  a single `gh` call, return every failing check on its own line, create nothing on a refusal, and
  print the number under the kind's own label on success. Neither takes `--role`, and the shapes are
  why: `item-tech-debt.md` names no role at all, and `item-bug.md` carries its role in the body's first
  line, where the placeholder scan already refuses it unfilled — a flag would write a second copy of a
  fact with nothing holding the two equal. A board that wants `role:<r>` on one of these adds it with
  `gh issue edit --add-label`, which skips no check, because every check here is on the body.

  > **Correction, filed as #41 and fixed in `0.8.1`.** One of those three reasons was not true when
  > this entry was published: the placeholder scan did *not* refuse an unfilled role. `item-bug.md`
  > writes the role inside a code span, and the scan strips code spans before it looks for stubs, so the
  > one stub naming an owner was the one stub it could never report — fifteen of that template's sixteen
  > were found and that one was not. A bug could be filed with its role still reading `<crew role>` and
  > nothing said so. The sentence holds from `0.8.1` onwards, and the decision it was
  > offered in support of stands on the other two reasons, which never depended on it: no command reads a
  > role label off a bug or tech-debt row, and a flag would write a second copy of a fact with nothing
  > holding the two equal.

- **`ensure-labels` mints `bug` and `tech-debt`** (#21). Without them a consuming board had no label to
  carry either shape, and `lint --kind tech-debt` named a kind nothing on a fresh board could be.
  `tech-debt` is new (`8D6E63`). `bug` is minted in GitHub's own `D73A4A` on purpose — GitHub creates
  that label in every new repository, and the `--force` every label here carries would otherwise
  repaint one a project already uses for exactly this. The description it does rewrite: an existing
  `bug` comes out as "Reported defect in behaviour that shipped (crew pipeline)".
- **A command whose answer the lead will report runs bare and alone** (#18). Rule 16 of
  `templates/operating-model.md` covered the project's gates only, and a lead's day is mostly other
  verification — a search, a count, a push, a comparison of two git objects — composed into one call
  with `&&` to save a round trip. It now states the general discipline with the four specifics the
  evidence supports: nothing chained after the command being judged, because the exit code that comes
  back then belongs to the last command in the line; an absence or a count in a call of its own,
  because `grep -c` and `rg` exit non-zero on zero matches, which is the answer when it stands alone
  and a poisoned chain when it does not; a pattern written against text that has been read rather than
  from memory of a file; and two git objects compared as `<ref>^{commit}`, because on an annotated tag
  `git rev-parse` returns the tag object, which is equal to no commit. Rule 8 and the token-economy
  bullet point at it instead of restating a narrower version, and step 5 of `/crew:work` names it
  rather than repeating it.
- **A rendered task body's `## Files` instruction reads as English where no generated paths are
  declared** (#25). `item-task.md` put `<profile:generated>` in the middle of a sentence, and the
  substitution for an absent key is a whole clause, so a profile with no `generated:` key — two of the
  three measured, this repository's own among them — rendered "Files matching nothing — no
  `generated:` paths are declared, so every file in this list counts are counted in G and do not spend
  the cap". Correct, and unreadable, in the first body a new project renders. The placeholder moves to
  the end of the block on its own labelled line, where a clause and a glob list both fit.
- **Thirty-four witness cases, over behaviour that already worked and nothing asserted** (#20, #21,
  #23, #26). `tracker.test.sh` goes from 38 cases to 49: the size checks with the ceiling off
  (`size-cap: -` still refuses a body stating no size, one whose size is not a number and one whose
  number disagrees with its `## Files` list, and accepts twenty files so the arm proves the ceiling
  really is off), a conforming submission that comes back out of the stored body byte for byte under
  the two header lines, an accepted `Exception:` keeping its reason, every bullet counting where no
  `generated:` key is declared, a claim on a pre-upgrade item asserted in all four of its clauses, the
  four cases that hold the two new create arms, a `## Proves` section that names no criterion, and the
  placeholder scan reached from all four kinds rather than from `story` alone.
  `review-contract.test.sh` goes from 27 to 50: the severity obligations in all five files that file a
  finding — a `p1` fixed before the change is offered, a `p2` fixed here when this change caused it or
  made it reachable, a pre-existing `p2` deferred to one line and its own item — each as a regex over
  the wording that is actually there, because those five word the sentence differently; and the
  one-round ceiling both by its presence, in the review step and in the README, and **by its absence**,
  one check that searches every Markdown file the plugin ships for a sentence permitting a second round
  and passes on finding none. Both suites were already on the `test:` and `gates:` lines of **this
  repository's own** `.claude/crew/profile.md`; nothing is asked of your profile.

### What to do

1. Install it: `claude plugin install crew@claude-crew`.
2. **Re-run `scripts/tracker.sh ensure-labels`.** This is the one required action and nothing does it
   for you — `/crew:init` runs it at setup, and an upgrade does not run `/crew:init`. Until it has run
   the board has no `tech-debt` label for `tracker.sh tech-debt create` to file under, and `lint --kind
   tech-debt` reads a kind the board cannot hold. It is idempotent, `--force` on every label; on a board
   that already carries a `bug` label the one thing it changes is that label's description.
3. If `/crew:init` rendered `.github/ISSUE_TEMPLATE/` for you, re-run `/crew:init --refresh`, which
   also does step 2. `templates/item-task.md` changed, so the task template a human files through keeps
   the unreadable `## Files` instruction until you do, and `/crew:status` prints `issue templates:
   rendered from crew <rendered>, installed is 0.7.0 (/crew:init --refresh)` under the board meanwhile.
   A project that declined that render, or has taken those files over, has nothing to do here.

Nothing else: no profile key, no item section and no flag on an existing command is new. A project that
has taken a kind over with its own `.claude/crew/items/<kind>.md` keeps that copy, including — for
`task` — the `## Files` sentence this release fixed in the plugin's.

### What happens if a project changes nothing

Two things, and nothing else:

1. **`tech-debt create` has no label to file under**, and `lint --kind tech-debt` reports on a label the
   board does not carry. `bug create` works wherever GitHub's own `bug` label is still there, which is
   every repository that has not deleted it. Neither command existed before this release, so nothing
   that worked stops working.
2. **Everything that existed under `0.6.1` behaves as it did.** Rule 16 is read by the lead, not
   executed; the `## Files` sentence is read by whoever drafts a task body; the witness cases run in
   this repository against its own profile. Every command keeps its flags, its output and its exit
   codes — `lint`'s 2, and `next`'s and `status`'s stderr warning beside their exit 0, among them.

There is no migration tooling past those two steps, no version negotiation and no compatibility matrix.

## 0.6.1 — 2026-10-01

Patch, not minor: nothing is added. Every change below is a fix to behaviour `0.6.0` already
described — one report sentence that was untrue, and three reads that passed a partial board off as
the whole one. No command, flag, profile key, label or item section is new, and no output that was
already correct changes shape. The one thing a caller could trip over is `lint`'s new exit 2, and it
fires only where `0.6.0` returned a `0` it had not earned; "What happens if a project changes
nothing" says what that means for a script written around it.

### What changed

- **`lint` says when a fetch filled its limit instead of printing a partial read as a clean board**
  (#14). `0.6.0` fetched 500 items per kind and said nothing when a kind held more, so a board past
  500 of one kind reported a count that read as complete over items it had never seen. The cap is now
  2000 per kind — `--limit N` is an exact cap that `gh` pages the API to satisfy, so the cost is the
  pages a board actually fills — and a fetch that comes back exactly full names the kind and the limit
  in the closing line and exits 2, which is a partial read and not the verdict exit 1 gives. Read
  further into the kind that filled with `lint --kind <kind>`, which gives each kind its own budget.
  **This retracts `0.6.0`'s "Honest limits" note about the 500 cap**: a reader told there to treat
  `lint`'s count as a lower bound until this was fixed no longer has to, because the count now says
  for itself when it is one.
- **`next` and `status` say when a fetch filled its limit instead of passing a partial board off as
  the whole one** (#16). The three fetches behind them — open tasks, tasks of every state, open
  stories — capped at 200, 500 and 100 and said nothing when a label held more, so a large board could
  keep a claimable task out of `/crew:next` and drop a story off `/crew:status` with no sign at all.
  All three now share the same 2000-item cap, and a fetch that comes back exactly full warns on
  **stderr**, naming which of the three filled and what it costs the reader. **stdout and the exit
  code are unchanged, deliberately**: unlike `lint`, these two are not reporters — every row they
  print is real and claimable, so a filled fetch makes the output incomplete rather than wrong, and a
  non-zero exit would have `/crew:next --auto` read "there is more" as "this failed" and refuse work
  that is genuinely there.
- **The setup report and the three resolution lines no longer promise that a project's own item shape
  wins whole** (#15). `0.6.0` described an override as deciding the whole shape. It decides the
  required sections; the `Story: #<n>` first line and the `Blocked by:`, `Role:` and `Size:` lines are
  checked against the adapter's own rules whatever the override contains, because the board's rollup
  reads them. A project that believed the sentence and dropped `Size:` had every task creation refused
  with nothing explaining why. The enforcement was right, so only the wording changed — in
  `/crew:init`'s report and in `/crew:conform`, `/crew:plan` and `/crew:refine`, and in
  `templates/item-task.md`'s own header comment, which had named only the `Story:` line.
- **The three hook commands are quoted** (#15). `hooks/hooks.json` interpolated
  `${CLAUDE_PLUGIN_ROOT}` unquoted in all three entries, which printed three warnings on every
  `claude plugin validate` run and exits 127 from an install whose plugin root contains a space.
- **Both caps are witnessed.** `scripts/tests/tracker.test.sh` now asserts the limit each fetch hands
  `gh` — the stub truncates to it, so a call hard-coded to the wrong number cannot stay green — that
  saturation reaches `lint`'s closing line with exit 2 and `next`'s and `status`'s stderr with exit 0
  and rows alone on stdout, that a warning fires for the fetch that actually filled and not for its
  siblings, and that a non-numeric cap falls back to 2000 instead of switching the comparison off in
  silence. Still four witnesses, all on the `test:` and `gates:` lines of **this repository's own**
  `.claude/crew/profile.md`; nothing is asked of your profile.

### What to do

1. Install it: `claude plugin install crew@claude-crew`.
2. If `/crew:init` rendered `.github/ISSUE_TEMPLATE/` for you, re-run `/crew:init --refresh`. This is
   the one action an upgrading project needs, and the easiest to miss: those files carry the version
   they were rendered from, so `/crew:status` prints `issue templates: rendered from crew 0.6.0,
   installed is 0.6.1 (/crew:init --refresh)` under the board until you do — and the refresh is also
   how the corrected `item-task.md` header reaches the copy a human files through. A project that
   declined that render, or that has taken those files over, has nothing to do.

Nothing else: no profile key, no label, no command and no item body changes. A project whose own
`.claude/crew/items/task.md` dropped `Blocked by:`, `Role:` or `Size:` on `0.6.0`'s wording does still
have to put those three lines back, but that is a `0.6.0` refusal this release only stops
mis-describing, not a new requirement.

### What happens if a project changes nothing

Three things, and nothing else:

1. **`lint`'s exit code gains the value 2**, so a project that put `lint` behind something reading its
   exit code should know 2 means "read incompletely" rather than "items failed". It fires only on a
   board holding 2000 or more items of one kind — which is precisely where `0.6.0` exited 0 over items
   it had never read, so a wrapper that trusted that 0 was already being told the wrong thing.
   Nothing in this plugin reads it: the `gates:` line deliberately carries no `lint`, and every other
   consumer is prose a human or an agent reads.
2. **`next` and `status` may write one line to stderr.** Their stdout and their exit 0 are what they
   were, so anything parsing the rows is untouched; a caller that folds stderr into stdout with
   `2>&1` sees the warning among them.
3. **`/crew:status` prints the issue-template version line** above until the render is refreshed or
   removed. It is a string compare of two versions and says nothing about the bodies.

There is no migration tooling past that one optional re-render, no version negotiation and no
compatibility matrix.

## 0.6.0 — 2026-10-01

Minor, not patch: the item templates and `/crew:conform` are new capability, the four profile keys
are additive with stated fallbacks, and one existing behaviour changes — `story create` and
`task create` now refuse a body that is off-shape.

One output changes shape too: `tracker.sh show <n>` printed comments only and now prints the item,
then `--- comments ---`, then the comments. Anything parsing that output breaks. Nothing in this
repository parses it — the skills that call `show` read it, and no test or script asserts on its
shape — so it is minor here; if you have a script around `show`, read it before you upgrade.

### What changed

- **Every item has one shape.** Four bodies ship with the plugin and are read at runtime —
  `templates/item-story.md`, `item-task.md`, `item-bug.md`, `item-tech-debt.md`. A project replaces
  one kind by putting its own complete copy at `.claude/crew/items/<kind>.md`; nothing is copied into
  a project.
- **The shape is enforced by refusal at creation.** `tracker.sh story create` and `task create`
  refuse a body that misses a section or a header line, and `Story: #<n>` is now a checked first-line
  contract — the line the board's rollup has always needed.
- **One size contract.** A task body carries `Size: <H> hand-written files (+ <G> generated) · <T>
  RED tests · one PR`, a `Split line:` naming the seam it is cut at, and `Exception: <reason>` for a
  mechanical sweep. The default ceiling is 15 hand-written files, moved with `size-cap:` and removed
  with `size-cap: -`. The count is checked at creation, printed at claim, and compared against the
  committed diff before any reviewer is briefed.
- **`tracker.sh lint [<n> | --all | --kind …] [--quiet]`** reports every board item that no longer
  matches its kind's template, one line per item naming each failing check, exit 1 when any fails.
  It only reads. `/crew:status` prints its count under the board.
- **`/crew:conform [<n> | --all]`** brings a board filed before the shape over to it in one pass:
  it drafts the fixes a body already decides, briefs the owning role read-only for new text, and
  shows a diff per item before anything is written. With nobody to approve a diff, the pass refuses.
- **Four new profile keys**, each safe by its absence: `generated:` (globs whose files do not count
  toward the size), `size-cap:`, `definition-of-done:` and `merge-authority:`. An absent key renders
  its fallback in the item body, where the writer reads it.
- **`/crew:init` learns them** — it fills `generated:` by scanning and marks the guess in the profile
  itself, asks for the other three, and offers to render the issue templates (off by default).
- **A reviewer is isolated.** A review brief carries the diff, the reviewed commit, the criteria with
  their text, the design's contracts, the profile and the findings format — and may not carry the
  implementer's report, the lead's narrative or an earlier round's findings. A reported problem that
  names no command and quotes no line is a question, not a finding, and never enters a fix round.
  One round of agent review is the ceiling; a contested finding goes to the user.
- **The model a run used is provable.** `scripts/subagent-model.sh audit [<session-dir>]` walks the
  session's own files and prints one row per run — the model the dispatch asked for beside the model
  that ran — flagging `MISMATCH` and `DISPATCH-CONFLICT`, exit 1 when any stands. `/crew:status` and
  `/crew:work` print it at every task boundary. The `SubagentStop` hook is best-effort and is no
  longer described as the proof.
- **Every persona's model tier is stated once**, in the README's "Model per role" roster, with what
  the tier buys against and what would move it. `scripts/tests/model-roster.test.sh` holds the
  roster's Default column against the persona frontmatter.
- **`tracker.sh release <n> --to done`** is the transition that means finished: lane labels off, item
  closed, assignee kept. `/crew:work` step 7 finishes an item when its PR is merged, whoever merged
  it. Before this, a closed item kept `in-progress` and the board counted it as in flight.
- **`tracker.sh show <n>`** prints the item and then its comments, separated by `--- comments ---`.
  It printed only the comments before, which hid every body from the two pipeline steps that open on
  it.
- **`plan` and `refine` read the shipped shapes.** Both resolve the item body before briefing anyone
  — `.claude/crew/items/<kind>.md` if the project has one, else the plugin's
  `templates/item-<kind>.md` — and hand the architect or the product-owner that rendered body to
  fill. Neither invents a shape from prose any more.
- **QA gets no worktree it cannot use.** `/crew:work` step 4 and `/crew:review` step 1 create the
  qa-engineer's mutation worktree only when the diff changes code a test protects. For a docs-only
  diff, or a script nothing builds or imports, no worktree is made, the brief says the mutation
  review is not applicable, and the PR says so too.
- **`ensure-labels` mints the review severities.** It now creates `p1`, `p2` and `p3` alongside the
  lane and `role:*` labels, so a review finding has a label to carry.
- New: `scripts/tests/review-contract.test.sh`, `scripts/tests/model-roster.test.sh`. Four witnesses
  now — all on the `test:` and `gates:` lines of **this repository's own**
  `.claude/crew/profile.md`, which is what the plugin is developed against. Nothing is asked of your
  profile.

### What to do

1. Install it: `claude plugin install crew@claude-crew`.
2. Re-run `scripts/tracker.sh ensure-labels`. This is the one action an existing board needs: `p1`,
   `p2` and `p3` are new, and a board set up before this release does not have them until you do.
   The command is idempotent and updates the labels it already made.
3. Optionally add the four new keys to `.claude/crew/profile.md` — `generated:`, `size-cap:`,
   `definition-of-done:` and `merge-authority:`. Each renders its fallback in the item body when
   absent, so a profile written for 0.5.9 is a valid 0.6.0 profile. `/crew:init` fills `generated:`
   by scanning and asks the other three.
4. Run `scripts/tracker.sh lint --all` to see which existing items are off-shape and so will
   warn at claim, then `/crew:conform` when you want them brought over. Do not add `lint --all` to
   your `gates:` line until that pass has run and the board reports zero non-conforming — otherwise
   every gate run goes red for items nobody has had the chance to migrate.

### What happens if a project changes nothing

Four things, and nothing else:

1. **On new bodies, from day one:** `story create` and `task create` refuse a body that does not
   conform. Nothing already on the board is touched.
2. **On old bodies, from day one:** `claim` succeeds and prints the failing checks as `warning:`
   lines. Every item stays claimable; no item is reshaped, refused or unclaimed for being old.
3. **On finished items, from day one:** `/crew:work` step 7 closes a merged item with
   `release --to done` instead of leaving it closed with a lane label on. Nothing retroactive:
   items closed before this release keep their stale lane label, and `status` keeps counting them as
   in flight, until someone takes it off by hand. No command in this release does that for you.
4. **When the project chooses, never before:** `lint --all` reports and `/crew:conform` migrates, and
   `conform` edits one item only after a human has approved its diff.

There is no migration tooling past that one command, no version negotiation and no compatibility
matrix.
