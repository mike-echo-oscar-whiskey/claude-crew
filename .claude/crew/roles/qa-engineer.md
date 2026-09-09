# qa-engineer — project addendum

- There is no automated test suite. The gate is `claude plugin validate .`, `bash -n` per script and `jq empty` per manifest; run it bare and quote each exit code.
- Behaviour of hooks and skills is proven by a smoke run: `claude --plugin-dir ./plugins/crew` from a scratch project, then the hook output on SessionStart and the /crew:* command in question. Quote the hook lines you saw.
- A mutation review of a script means changing one branch of it in your worktree and showing the gate or smoke run catches it; when nothing does, that is the finding.
