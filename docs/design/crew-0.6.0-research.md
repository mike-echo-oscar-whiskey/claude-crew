# 📝 docs(crew): what the industry does with agent-assisted development, 2026

Evidence base for `crew-0.6.0-items-and-proof.md`, gathered by the architect role 2026-09-30. Every claim carries its source and date; section 7 lists the claims that could not be verified.

# Agent-assisted software development in 2026 — the outside view

Research run, architect role, 2026-09-30. Scope: what the industry does and what the evidence
says; nothing here judges our repository, plugin or issues. Sources are primary where one exists
(vendor docs, studies with a method, engineering posts with numbers); each carries its date because
this field turns over in months. Evidence strength: **measured** (a method and numbers),
**reported** (a team's own numbers, not independently checked), **asserted** (no numbers).

## 1. Practice table

| Practice | Who does it | Claims to solve | Evidence | Date |
|---|---|---|---|---|
| Spec-driven development, full toolchain (specify → plan → tasks → implement) | GitHub Spec Kit, AWS Kiro, Tessl, BMAD | Vague prompts, drift between intent and code | **Asserted** by vendors (Spec Kit: "12 h of docs → 15 min", no study); **measured against** by two hands-on trials (Scott Logic, Marmelab) | Sept 2025 – Nov 2025 |
| Spec-first as a plan mode (short plan before coding, skip for one-sentence diffs) | Anthropic Claude Code, Cursor, Gemini CLI; Mercari "Agent Spec" | Solving the wrong problem | **Reported** (Mercari: one project "one month → one week"); Anthropic guidance is asserted | Dec 2025 – 2026 |
| Small, well-scoped issues with acceptance criteria and file pointers | GitHub (Copilot coding agent docs), Factory | Low merge rate of agent PRs | **Measured**: issue traits predict merge (AUC 0.72, arXiv 2512.21426) | Dec 2025, Sept 2026 |
| Small PRs / small batches | DORA capabilities model; practitioner reports | Review load, defect escape | **Measured** (Faros telemetry, 22k devs; Brodzinski two-project comparison) — correlational | Sept 2025 – July 2026 |
| Single writer, many advisers (no parallel writers) | Cognition (Devin) | Conflicting implicit decisions | **Reported** (production experience, no controlled numbers) | June 2025 → Apr 2026 |
| Orchestrator + subagents in isolated contexts | Anthropic | Context bloat, breadth-first work | **Measured** on Anthropic's internal eval (+90.2 %, research task, not coding); 3–10× / 15× tokens | June 2025, Jan 2026 |
| Clean-context reviewer (generator–verifier) | Cognition Devin Review; Anthropic best practices | Implementer blind to its own bugs | **Reported** (2 bugs/PR, 58 % severe); **measured** in a lab (CCR F1 28.6 % vs 24.6 % self-review, arXiv 2603.12123) | Mar–Apr 2026 |
| Model tiering per role | Anthropic (Opus lead / Sonnet subagents; Claude Code docs table) | Cost | **Measured** for research eval (2025) and for review benchmark (Haiku 4.5 > Sonnet 4.6, arXiv 2606.15689); everything else asserted | June 2025, Apr 2026 |
| AI code review as a gate | Many vendors; Microsoft 600k PRs/month | Reviewer capacity | **Measured against**: frontier models find 15–31 % of human-flagged issues (SWE-PRBench); F1 0.066 on real PRs | Mar–Apr 2026 |
| Mutation-guided test generation | Meta ACH | Coverage-maximising, mutant-transparent tests | **Measured** (73 % of tests accepted; equivalent-mutant detector P 0.79/R 0.47) | Jan–Feb 2025 |
| Human approves merge, always | GitHub, Cognition, Anthropic, Microsoft, DORA | Instability | **Consensus**; Anthropic autonomy data shows consequential actions stay gated | 2025–2026 |
| EARS / Given-When-Then criteria | Kiro (EARS), BDD community | Ambiguity | **Asserted for agents**; EARS has pre-LLM industrial validation only | 2009, 2025 |
| Criterion → test traceability | Spec Kit, Kiro, Factory, academic tools (REST-at, TraceDev) | Unverifiable "done" | **Asserted** in practice; academic tools measured on link accuracy, not delivery outcomes | 2026 |
| AI-written PR summaries | GitHub Copilot for PRs | Reviewer reading time | **Measured, correlational, pre-agent** (18,256 PRs, less review time, higher merge; arXiv 2402.08967) | Feb 2024 |

## 2. Findings per question

### 2.1 Spec-driven development

**What the artifact is.** Spec Kit produces `spec.md` (user stories + acceptance criteria, no
tech), `plan.md` (stack, data model, contracts), `tasks.md` (ordered, parallelisable tasks), under
a "constitution" of non-negotiable principles ([spec-driven.md](https://github.com/github/spec-kit/blob/main/spec-driven.md),
Sept 2025). Kiro produces `requirements.md` in EARS ("WHEN … THE SYSTEM SHALL …"), `design.md`,
`tasks.md`, with a human approval between each; its Quick Spec makes the same three files in one pass
without gates ([requirements-first](https://kiro.dev/docs/specs/feature-specs/requirements-first/),
[quick-spec](https://kiro.dev/docs/specs/quick-spec/)). Marc Brooker (AWS, agentic AI safety) defines
the useful spec as "an explicit statement of requirements and key design choices, separated from the
low-level implementation", a living artifact, mixing free text, EARS/RFC2119 or TLA+ where each pays
([brooker.co.za, 2026-04-09](https://brooker.co.za/blog/2026/04/09/waterfall-vs-spec.html)). He makes
no claim about Amazon-internal practice; none was found documented.

**Evidence for.** Vendor claims are asserted: the Spec Kit design doc has no study, no case, no
"when not to". The two academic SDD papers are position papers built on grey literature
([arXiv 2609.00252, 2026-08-31](https://arxiv.org/abs/2609.00252): "a first step toward consensus
rather than a validated theory"; [arXiv 2602.00180, 2026-01-30](https://arxiv.org/abs/2602.00180):
a guide with case studies). The "human-refined specs cut errors ~50 %" figure that a mid-2026 field
study attributes to the latter is **not in that paper's abstract; unverified**. Mercari's "Agent Spec"
is the strongest practitioner report: an agent drafts implementation instructions from the PRD plus
Slack/Notion context, the team reviews it, then implements; one project went from an estimated month
to a week ([engineering.mercari.com, 2025-12-09](https://engineering.mercari.com/blog/entry/20251209-d0de07214d/)).
The 150 %/80 % speed-up figures circulating for Mercari were not found in that post — **unverified**.

**Evidence against.** Scott Logic ran Spec Kit on a real feature: 33.5 min of agent time, 2,577
lines of Markdown for 689 lines of code, 3.5 h of human review, one obvious bug; iterative prompting
did the same feature in 8 min, 24 min of review, no bug
([2025-11-26](https://blog.scottlogic.com/2025/11/26/putting-spec-kit-through-its-paces-radical-idea-or-reinvented-waterfall.html)).
Marmelab tested Spec Kit, Kiro, Tessl and BMAD: 8 files and ~1,300 lines to show the current date;
agents marked tasks done without writing the mandated tests; "mostly unusable" on a large existing
codebase; fine on greenfield
([2025-11-12](https://marmelab.com/blog/2025/11/12/spec-driven-development-waterfall-strikes-back.html)).
Thoughtworks put SDD on Assess: "lengthy spec files that are hard to review … unclear who their
intended user is", and warns of "relearning a bitter lesson"
([Radar, Nov 2025](https://www.thoughtworks.com/radar/techniques/spec-driven-development)); a Thoughtworks
director adds that "spec drift and hallucination are inherently difficult to avoid", so deterministic
CI remains the safeguard ([2025-12-04](https://www.thoughtworks.com/en-es/insights/blog/agile-engineering-practices/spec-driven-development-unpacking-2025-new-engineering-practices)).
A July 2026 field study summarises the market: spec-first (a plan before code) went mainstream by being
absorbed into plan modes; spec-anchored (a living spec kept in sync) is contested because drift is
unsolved; spec-as-source stalled
([ianhxu field study, 2026-07-03](https://github.com/ianhxu/agentic-engineering-field-study/blob/main/04-spec-driven-development.md)).

**What the spec actually solves, and what it costs.** The consistent signal across sides is that the
value is in *deciding* requirements, out-of-scope and key design choices before code, and in having
the agent's assumptions reviewable before source changes. The cost is a third document that must be
read, kept in sync, and that agents ignore when it is long. Anthropic's own guidance is the sober
middle: "If you could describe the diff in one sentence, skip the plan"; for larger features, have
the agent interview you and write a spec that "names the files and interfaces involved, states what is
out of scope, and ends with an end-to-end verification step"
([code.claude.com best practices, 2026](https://code.claude.com/docs/en/best-practices)).

**Spec versus design.** Spec Kit's `spec.md` is the story (WHAT/WHY + acceptance criteria); its
`plan.md` is the design (contracts, data model); `tasks.md` is the breakdown. Nobody found shows a
spec artifact adding measurable value *on top of* a story with testable acceptance criteria plus a
design document — the tools bundle those three because most users start with none.

### 2.2 Sizing work for agents

- **PR size grows and review breaks.** Faros telemetry across 22,000 developers: under high AI
  adoption average PR size +51.3 %, files per PR +59.7 %, bugs per PR +54 %, median review time
  +441.5 %, code churn +861 %, incidents per PR +242.7 %, PRs merged without review +31.3 %; "high
  performing organizations experience the same downstream deterioration"
  ([Faros, 2026-04-12](https://www.faros.ai/blog/ai-acceleration-whiplash-takeaways)). Correlational, no
  control, vendor data. Brodzinski compared two similar greenfield projects: heavy-Claude project PRs
  averaged 817 LOC vs 232 (3.5×), median 210 vs 66, large PRs 13 % → 33 %
  ([2026-07-14](https://brodzinski.com/2026/07/3x-pull-request-size-ai.html)).
- **DORA.** 2025: ~5,000 respondents, 90 % adoption, throughput *and* instability both up, 30 %
  little or no trust; "working in small batches" is one of the seven AI capabilities
  ([Google, 2025-09-23](https://blog.google/innovation-and-ai/technology/developers-tools/dora-report-2025/);
  [capabilities list](https://cloud.google.com/blog/products/ai-machine-learning/from-adoption-to-impact-putting-the-dora-ai-capabilities-model-to-work/)).
  2026 ROI report: a J-curve with a "verification tax" and modelled change-failure rise 5 → 6 %
  ([InfoQ, 2026-05-11](https://www.infoq.com/news/2026/05/dora-roi-ai-assisted-dev-report/)).
- **METR.** The RCT on experienced OSS developers found −19 % (CI +2 … +39 %) with early-2025 tools
  ([2025-07-10](https://metr.org/blog/2025-07-10-early-2025-ai-experienced-os-dev-study/)); the
  late-2025 follow-up gives −18 % (CI −38 … +9) for returning developers and −4 % (−15 … +9) for 47 new
  ones, and METR calls its own data "only very weak evidence" because developers skip tasks they will
  not do without AI ([2026-02-24](https://metr.org/blog/2026-02-24-uplift-update/)). The honest reading:
  no measured net speed-up for expert developers on their own large repos, wide intervals, likely a
  lower bound.
- **What predicts a mergeable agent PR.** Of 567 Claude Code PRs, 83.8 % were accepted, 54.9 %
  unmodified; human edits clustered on bug fixes and project-convention compliance
  ([arXiv 2509.14745](https://arxiv.org/abs/2509.14745), Sept 2025/Feb 2026). Issues that are
  shorter, well scoped, with hints about the relevant artifacts predict merge; issues needing external
  references (config, dependencies, external APIs) predict failure (AUC 0.72,
  [arXiv 2512.21426, 2025-12-24](https://arxiv.org/abs/2512.21426)). GitHub's own guidance: clear
  problem statement, complete acceptance criteria, which files, and split large tasks into sub-issues
  ([docs](https://docs.github.com/copilot/how-tos/agents/copilot-coding-agent/best-practices-for-using-copilot-to-work-on-tasks)).
  Factory's task shape: outcome, repo + scope + explicit out-of-scope, independently testable criteria
  (trigger, expected result, distinguishing detail), exact verification steps, links not chat history,
  negative cases; "read the specification as a reviewer" before delegating
  ([2026-09-24](https://factory.com/articles/coding-agent-task-specifications)).

### 2.3 Multi-agent orchestration

- **Cognition, June 2025**: don't build multi-agents; share full traces, not messages; actions carry
  implicit decisions and parallel agents make conflicting ones; single-threaded agent plus a
  compressor for long runs ([2025-06-12](https://cognition.com/blog/dont-build-multi-agents)).
- **Cognition, April 2026** (revision, not retraction): what works is *one writer, many advisers* —
  a generator–verifier loop where the reviewer runs on **fresh** context (Devin Review: ~2 bugs per PR,
  ~58 % severe, on PRs Devin wrote), a manager agent that scopes multi-PR work and spawns children, and
  a "smart friend" where a cheaper primary consults a frontier model. Parallel-writer swarms still fail
  ([2026-04-22](https://cognition.com/blog/multi-agents-working)).
- **Anthropic, June 2025**: Opus 4 lead + Sonnet 4 subagents beat single Opus by 90.2 % on an internal
  *research* eval (breadth-first search, not code); agents use ~4× chat tokens, multi-agent ~15×;
  failure modes were vague delegation and mis-sized effort, fixed by task descriptions that state
  objective, output format, tools and boundaries
  ([engineering post](https://www.anthropic.com/engineering/multi-agent-research-system)).
- **Anthropic, January 2026**: use subagents for context protection (subtask emits >1,000 tokens
  mostly irrelevant to the main task), parallelism, or specialisation; failure modes are context loss at
  hand-off, the telephone game, and agents spending more tokens coordinating than executing; expect
  3–10× tokens; "decompose by context boundaries, not problem types"
  ([claude.com blog, 2026-01-23](https://claude.com/blog/building-multi-agent-systems-when-and-how-to-use-them)).
  The Claude Code docs add the operational warning: a subagent sees no history, no earlier decisions,
  no files already read — every decision it needs must be restated in its brief
  ([sub-agents docs](https://code.claude.com/docs/en/sub-agents)).
- **Convergence.** Both camps now say the same thing: one writer per change; isolated contexts for
  reading, researching and verifying; a lead that holds scope; parallel writers only on disjoint work.
  Cost per task is the price: 3–15× tokens, reported by Anthropic, not contradicted by anyone.

### 2.4 Model tiering per role

Published, measured tiering is thin. Anthropic's Opus-lead/Sonnet-subagent split was measured on a
research eval (June 2025). The Claude Code docs give a table — haiku/sonnet for read-only exploration,
sonnet/opus for review, opus for high-stakes decisions — without numbers
([sub-agents docs](https://code.claude.com/docs/en/sub-agents)). One study measured review
specifically: Haiku 4.5 beat Sonnet 4.6 on a 150-sample review benchmark (F1 0.365 vs 0.343, 18 %
higher recall, 3.2× cheaper), but on the 50 *real* PRs the best model reached F1 0.066 versus 0.847 on
synthetic bugs — a 92 % drop ([arXiv 2606.15689, 2026-04-09](https://arxiv.org/abs/2606.15689)).
Cognition's "smart friend" pattern reports that a weaker primary consulting a stronger model works
when both are capable and fails when the primary lags far behind (April 2026). Vendor "routing guides"
recommending Opus-plan/Sonnet-build/Haiku-review are asserted, not measured. Net: tier the cheap
read-only roles with confidence; tier the reviewer only with a measured re-prompt rate; keep the role
that holds decisions on the strongest model.

### 2.5 Issue and PR hygiene for a mixed audience

- **Work-item shape** is measured (2512.21426) and consistent across GitHub, Factory and Anthropic:
  outcome, scope and out-of-scope, testable criteria, file pointers, a verification step, links rather
  than pasted history; keep it short; avoid anything that needs external systems.
- **Given/When/Then vs plain lists**: no study comparing criterion formats for agent outcomes was
  found. EARS has requirements-engineering validation from before LLMs (Rolls-Royce, 2009); Kiro adopted
  it; Factory's "trigger, expected result, distinguishing detail" is the same shape in prose. Verdict:
  **widely repeated, never measured**. The one measured fact nearby is that agents ignore long documents
  (Marmelab, Thoughtworks), which argues for short criteria over ceremonial ones.
- **Traceability criterion → test**: every SDD tool asserts it; academic tools measure link accuracy
  (REST-at at AST 2026, TraceDev) not delivery effect. Anthropic's practical form is "end with an
  end-to-end verification step" and "have Claude show evidence rather than asserting success".
- **TL;DR summaries**: the only measured item is pre-agent — Copilot-generated PR descriptions
  correlated with less review time and higher merge on 18,256 PRs, causality not established
  ([arXiv 2402.08967, 2024-02-14](https://arxiv.org/abs/2402.08967)). A counter-finding matters more for
  agent reviewers: framing in a PR description systematically shifts LLM security verdicts, with refined
  descriptions flipping verdicts in 32/33 real CVE cases against Claude Code and CodeRabbit pipelines
  ([arXiv 2603.18740, Mar–Sept 2026](https://arxiv.org/abs/2603.18740)). A summary helps the human;
  it should never be the reviewer agent's input.

### 2.6 Quality gates

- **Agent review recall is low.** Eight frontier models find 15–31 % of human-flagged issues on
  350 PRs, diff-only ([SWE-PRBench, 2026-03-27](https://arxiv.org/abs/2603.26130)); F1 0.066 on real
  PRs (2606.15689). Vendor benchmarks (Greptile, July 2025, 50 PRs) report recall 82/58/54/44/6 % for
  Greptile/Bugbot/Copilot/CodeRabbit/Graphite with 11 vs 2 false positives — a recall/precision trade,
  vendor-run ([secondary](https://dev.to/jovan_chan_9500711396d4e6/greptile-review-2026-82-bug-catch-rate-the-1review-trap-and-who-should-pay-30month-4jao)).
- **Confidently wrong findings are a known pattern.** Anthropic's own callout: "A reviewer prompted to
  find gaps will usually report some, even when the work is sound … Tell the reviewer to flag only gaps
  that affect correctness or the stated requirements" (best practices, 2026). Self-review is worse than
  useless as a gate: a model gating its own output enters "a rubber-stamp regime where acceptance scores
  rise while benchmark correctness falls" ([arXiv 2606.28438, 2026-06-26](https://arxiv.org/abs/2606.28438));
  a second self-review in the same session scored *lower* than one (F1 21.7 % vs 24.6 %), a context-aware
  subagent no better (23.8 %), a fresh-session reviewer best (28.6 %, p ≤ 0.008)
  ([arXiv 2603.12123, 2026-03-12](https://arxiv.org/abs/2603.12123)). Cognition found the same in
  production: the reviewer "performs best with completely fresh context". Framing attacks (2603.18740)
  show the reviewer also inherits the implementer's story if given it.
- **Humans are not reviewing agent PRs.** Of 33,596 agent-authored PRs on 100+-star repos, 61.38 %
  had no review at all and 71.58 % of review comments were by agents
  ([arXiv 2605.02273, 2026-05-04](https://arxiv.org/abs/2605.02273)); a 3,100-document grey-literature
  study concludes "review is the control point through which a coding agent's effect on software is
  decided" ([arXiv 2607.07980, 2026-07-08](https://arxiv.org/abs/2607.07980)).
- **Mutation testing.** Meta's ACH generates issue-specific mutants and tests that kill them:
  10,795 classes, 571 tests, 73 % accepted by engineers; an LLM equivalent-mutant detector at
  P 0.79/R 0.47, rising to 0.95/0.96 with pre-processing
  ([arXiv 2501.12862, FSE 2025](https://arxiv.org/abs/2501.12862);
  [Meta engineering, 2025-02-05](https://engineering.fb.com/2025/02/05/security/revolutionizing-software-testing-llm-powered-bug-catchers-meta-ach/)).
  Practitioners report agent-written tests that maximise coverage and assert nothing — "mutant-transparent"
  ([awesome-testing, Aug 2026](https://www.awesome-testing.com/2026/08/mutation-testing-for-agent-written-code)).
- **When a human must be in the loop.** Consensus across GitHub, Cognition, Anthropic, Microsoft
  (600k PRs/month AI-reviewed, "the author remains in control",
  [2025-07-14](https://devblogs.microsoft.com/engineering-at-microsoft/enhancing-code-quality-at-scale-with-ai-powered-code-reviews/)):
  merge is human. Anthropic's autonomy data: experienced users auto-approve >40 % of actions but interrupt
  more, and gate consequential ones ([2026-02-18](https://www.anthropic.com/news/measuring-agent-autonomy)).
  The verification ladder (deterministic → rule → field truth → model-as-judge → human) puts 70 % of
  real autonomous loops at the deterministic levels ([arXiv 2607.00038, 2026-06-28](https://arxiv.org/abs/2607.00038)).
  A 19-developer interview study finds supervisors concentrate effort in planning, delegate oversight to
  agents, and turn recurring guidance into reusable assets ([arXiv 2609.24234, 2026-09-21](https://arxiv.org/abs/2609.24234)).

## 3. Adopt / adapt / avoid — for one developer, one human reviewer, agents implementing

**Adopt**

- *Clean-context reviewer fed the diff and the criteria, nothing else, mandated to report
  correctness gaps only.* The lab (2603.12123), production (Cognition 2026-04), the framing study
  (2603.18740) and Anthropic's callout all point the same way: separation of context beats repetition,
  the implementer's narrative biases the verdict, and an open-ended "find gaps" mandate manufactures
  findings. Expect 15–31 % recall: the agent reviewer is a net under the human, never the gate.
- *A runnable verification per task, named in the task before implementation.* Anthropic ("give
  Claude a check it can run"), Factory ("exact verification steps"), the loop-engineering corpus (70 %
  deterministic) and DORA's small-batch capability converge; it is also the only defence against
  "marked done, no test written" (Marmelab). Pair it with mutation on the changed lines — Meta shows
  mutant-guided tests are the tests engineers accept.
- *A hard PR-size ceiling decided at planning, not at review.* Faros and Brodzinski show size
  drifting 2.5–3.5× under agents while review time explodes; with one human reviewer the ceiling is the
  throughput limit of the whole pipeline. Split before the agent starts (GitHub sub-issues), not after.
- *The measured work-item shape*: outcome, scope + out-of-scope, testable criteria, file pointers,
  verification, links not history; short. (2512.21426, GitHub, Factory.)

**Adapt**

- *Spec-first, not spec-driven.* Keep a written plan only for changes that cannot be described in one
  sentence (Anthropic), let the agent draft it from the story and the codebase and have the human
  correct it (Mercari), and keep it to requirements + key design choices (Brooker). A story with
  acceptance criteria plus a design document already *is* that artifact; do not add a third.
- *Model tiering.* Cheap models for read-only exploration is safe by every source. For review, the
  one measurement favours the cheaper model but on real PRs every model is weak — tier it with a
  measured re-prompt or missed-finding rate, not by assertion. Keep whoever holds decisions on the
  strongest model (Cognition's "smart friend" caveat).
- *Lead + specialists.* Industry-supported as "one writer, many advisers": a lead that holds scope,
  specialists that read/verify in isolation, one writer per change, parallel writers only on disjoint
  diffs, every decision restated in each brief because the specialist sees none of the history.

**Avoid**

- *A per-task SDD toolchain (Spec Kit / Kiro feature specs).* Measured against on real features
  (Scott Logic: ~4× the wall time, ~9× the review time, same bugs; Marmelab: 1,300 lines for a date);
  no measured evidence for; the tools' own designers publish none.
- *Parallel writer swarms* — the one pattern both Anthropic and Cognition still reject.
- *Iterated agent review rounds in the same session hoping for convergence* — a second pass scores
  lower than the first (2603.12123). One fresh reviewer, then the human.
- *Treating "reviewed by an agent" as coverage* — 61 % of agent PRs get no human review and the
  literature names review as the control point; a reviewer that saw the implementer's report is not
  independent.
- *Mandatory EARS/Given-When-Then* — no evidence for agents; the cost (long documents agents skip)
  is documented. Use the shape when a criterion is a state transition, prose otherwise.

## 4. First three, in order, and what each replaces in a lead-plus-specialists pipeline

1. **Reviewer isolation**: the review brief carries the diff, the acceptance criteria and the design's
   contracts — never the implementer's report or the lead's narrative — and the mandate "correctness
   and stated requirements only; everything else is optional". Replaces any review round where the
   reviewer reads what the implementer said it did.
2. **Verification named before implementation**: every task states the command or test that proves
   each criterion, the implementer quotes its output, and mutation runs on the changed lines. Replaces
   "tests expected" prose and post-hoc test review.
3. **Split at planning to a size ceiling**: the lead sizes tasks so the single human can read the
   whole diff; a task that would exceed the ceiling becomes two before any agent starts. Replaces
   "aim for small PRs" as advice and re-splitting after a fix round.

## 5. Specifically on SDD

**Recommendation: do not add a spec artifact.** A story with testable acceptance criteria plus an
existing design document covers exactly what Spec Kit's `spec.md` and `plan.md` hold, and what Brooker
says the spec is for. The measurable benefits claimed for SDD (fewer wrong-problem implementations,
agent assumptions reviewable before code) come from having *any* written intent and key design
choices reviewed by a human before implementation — which is the plan-mode practice that went
mainstream — not from the third document, the constitution or the phase gates.

**The case for it, stated fairly.** A spec is *external behaviour* written precisely enough that a
test can be derived line by line (inputs/outputs, pre/postconditions, invariants — Thoughtworks
2025-12); a design document usually is not, and acceptance criteria are often too coarse. Where our
criteria are vague, SDD's discipline would expose it. Mercari's report, the one credible practitioner
gain, is real — but its "Agent Spec" is agent-drafted implementation guidance reviewed by the team, i.e.
a design document by another name. Brooker's living-spec argument holds for long autonomous runs; the
sources show those runs are what SDD optimises for, and a one-reviewer project is throughput-bound on
the human, not on agent autonomy.

**What to take from SDD without the artifact**: criteria written so that each names its test;
out-of-scope stated explicitly; key design choices recorded where the implementer reads them; the
human reviews the plan before code for anything larger than a one-sentence diff.

## 6. Already best practice, from what the brief describes

Judged only from the brief's description of the crew (the repository was not read): a design step
before implementation (spec-first, mainstream 2026); a human who alone merges (universal consensus);
mutation testing on changed lines (Meta, practitioner reports); a fresh agent per fix round (matches the
cross-context finding); reviewer roles distinct from the implementer (generator–verifier); short
subagent reports (Anthropic's 1–2k-token summaries); model tiering with the decision-holder on the
strongest model. These match the evidence; the gap the industry names is *what the reviewer is shown*
and *how tasks are sized before they start*, not whether a reviewer or a design exists.

## 7. Unverified or blocked

- Mercari "150 % faster than baseline, 80 % over freeform prompts": circulating in secondary
  summaries; not in the Mercari post fetched. Unverified.
- "Human-refined specs reduce errors ~50 %" attributed to arXiv 2602.00180: not in that abstract.
  Unverified.
- Walden Yan's X article "Multi-Agents: What's Actually Working" returned 403; the Cognition blog
  version of the same piece (2026-04-22) was used instead.
- DORA 2025 full report PDF not fetched; numbers taken from Google's launch post and the capabilities
  list on Google Cloud's blog.
- Greptile's July 2025 benchmark: vendor-run, read through secondary coverage; treated as reported.
- The 31.7 % "self-review missed behaviour-changing outputs" figure (Py2→3 study) reached only through
  a secondary site; not independently fetched.

## 8. Sources (all fetched or searched 2026-09-30)

- https://github.com/github/spec-kit/blob/main/spec-driven.md (2025)
- https://kiro.dev/docs/specs/feature-specs/requirements-first/ ; https://kiro.dev/docs/specs/quick-spec/
- https://brooker.co.za/blog/2026/04/09/waterfall-vs-spec.html (2026-04-09)
- https://marmelab.com/blog/2025/11/12/spec-driven-development-waterfall-strikes-back.html (2025-11-12)
- https://blog.scottlogic.com/2025/11/26/putting-spec-kit-through-its-paces-radical-idea-or-reinvented-waterfall.html (2025-11-26)
- https://www.thoughtworks.com/radar/techniques/spec-driven-development (Nov 2025)
- https://www.thoughtworks.com/en-es/insights/blog/agile-engineering-practices/spec-driven-development-unpacking-2025-new-engineering-practices (2025-12-04)
- https://arxiv.org/abs/2609.00252 (2026-08-31) ; https://arxiv.org/abs/2602.00180 (2026-01-30)
- https://github.com/ianhxu/agentic-engineering-field-study/blob/main/04-spec-driven-development.md (2026-07-03)
- https://engineering.mercari.com/blog/entry/20251209-d0de07214d/ (2025-12-09)
- https://code.claude.com/docs/en/best-practices ; https://code.claude.com/docs/en/sub-agents (2026)
- https://www.faros.ai/blog/ai-acceleration-whiplash-takeaways (2026-04-12)
- https://brodzinski.com/2026/07/3x-pull-request-size-ai.html (2026-07-14)
- https://blog.google/innovation-and-ai/technology/developers-tools/dora-report-2025/ (2025-09-23)
- https://cloud.google.com/blog/products/ai-machine-learning/from-adoption-to-impact-putting-the-dora-ai-capabilities-model-to-work/
- https://www.infoq.com/news/2026/05/dora-roi-ai-assisted-dev-report/ (2026-05-11)
- https://metr.org/blog/2025-07-10-early-2025-ai-experienced-os-dev-study/ ; https://metr.org/blog/2026-02-24-uplift-update/
- https://arxiv.org/abs/2509.14745 (2025-09/2026-02) ; https://arxiv.org/abs/2512.21426 (2025-12-24)
- https://docs.github.com/copilot/how-tos/agents/copilot-coding-agent/best-practices-for-using-copilot-to-work-on-tasks
- https://factory.com/articles/coding-agent-task-specifications (2026-09-24)
- https://cognition.com/blog/dont-build-multi-agents (2025-06-12) ; https://cognition.com/blog/multi-agents-working (2026-04-22)
- https://www.anthropic.com/engineering/multi-agent-research-system (2025-06-13)
- https://claude.com/blog/building-multi-agent-systems-when-and-how-to-use-them (2026-01-23)
- https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents (2025-09-29)
- https://arxiv.org/abs/2606.15689 (2026-04-09) ; https://arxiv.org/abs/2603.26130 (2026-03-27)
- https://arxiv.org/abs/2603.12123 (2026-03-12) ; https://arxiv.org/abs/2606.28438 (2026-06-26)
- https://arxiv.org/abs/2603.18740 (2026-03/09) ; https://arxiv.org/abs/2605.02273 (2026-05-04)
- https://arxiv.org/abs/2607.07980 (2026-07-08) ; https://arxiv.org/abs/2607.00038 (2026-06-28)
- https://arxiv.org/abs/2609.24234 (2026-09-21) ; https://arxiv.org/abs/2402.08967 (2024-02-14)
- https://arxiv.org/abs/2501.12862 ; https://engineering.fb.com/2025/02/05/security/revolutionizing-software-testing-llm-powered-bug-catchers-meta-ach/ (2025-02-05)
- https://www.awesome-testing.com/2026/08/mutation-testing-for-agent-written-code (2026-08)
- https://devblogs.microsoft.com/engineering-at-microsoft/enhancing-code-quality-at-scale-with-ai-powered-code-reviews/ (2025-07-14)
- https://www.anthropic.com/news/measuring-agent-autonomy (2026-02-18)
