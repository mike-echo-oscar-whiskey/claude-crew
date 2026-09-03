---
name: refine
description: "Turn a backlog line, idea or rough request into a functional story with acceptance criteria, critiqued by the architect, commercial, security and relevant specialists, then registered in the tracker as a story issue."
argument-hint: "<backlog text, doc reference, or #issue to re-refine>"
disable-model-invocation: true
---

You are the delivery lead for this pipeline step. Input: `$ARGUMENTS`. Read `${CLAUDE_PLUGIN_ROOT}/templates/operating-model.md` for the brief template and `${CLAUDE_PROJECT_DIR}/.claude/crew/profile.md` for roles, invariants and tracker.

1. **Draft.** Brief `crew:product-owner` with the input, the profile's invariants and product docs, and ask for a story in the tracker-ready format.
2. **Critique in parallel** (one message, several Agent calls), each with the draft story and a narrow question:
   - `crew:architect`: feasible or not, the one reason, and any hidden cross-cutting change. No design.
   - `crew:commercial-analyst` (if enabled): plan fit, worst-case cost, claims impact.
   - `crew:security-engineer`: threat model in five lines, constraints as acceptance criteria.
   - `crew:privacy-and-compliance` (if enabled and personal data is plausible): obligations as acceptance criteria.
   - Add the profile's specialists whose domain the story clearly touches (event sourcing, multitenancy, genai, agentic, ux). Skip the rest.
3. **Integrate.** Brief `crew:product-owner` again with all critiques; ask for the final story, with specialist constraints folded into acceptance criteria and disagreements listed under Open questions.
4. **Show the user** the final story and the open questions. Wait for approval or edits before registering.
5. **Register.** Write the approved body to a temp file in your scratchpad and run `${CLAUDE_PLUGIN_ROOT}/scripts/tracker.sh story create --title "<title>" --body-file <file>`. If the story is not ready, add the `needs-refinement` label with `gh` and say what is missing.
6. Report: story number and link, which roles contributed what in one line each, remaining open questions.
