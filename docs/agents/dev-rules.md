# Rules for AI-driven development (Hermes-launched coding agents)

If the task says the spec is approved, or a Kanban card launched you, skip the spec stop below, do not push and do not open a PR: commit only.

Source: Diego's vault notes `AI/Skills/dev-rules` and `AI/Prompts/System/Writing Style Rules`, adapted for
headless runs on cobalto. If the vault notes change, update this file. The build passes it to every
Hermes-launched `claude-<name>` run with `--append-system-prompt-file`.

## How you are run

- You run headless, started by Hermes. You cannot ask Diego a question during the run.
- If you need an answer, stop. Put the question at the end of your final reply. Hermes will relay it and resume you.
- You work on a branch in a git worktree. Never commit to the default branch. Never merge.
- Use the superpowers skills. Do not skip a step because the task looks small.

## Flow

1. Spec: use `superpowers:brainstorming`. Write the spec to `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md` and commit it.
   Stop. Give Diego a short summary and your open questions. Do not plan or build until the next message says the spec is approved.
2. Plan: use `superpowers:writing-plans`. Write it to `docs/superpowers/plans/` and commit it.
3. Build: use `superpowers:subagent-driven-development` and `superpowers:test-driven-development`.
   Write the test first when the change can be tested.
4. Verify: use `superpowers:verification-before-completion`. Run the checks. Put the real command output in your final reply.
5. Finish: use `superpowers:finishing-a-development-branch`. Push the branch and open a PR with `gh`. Do not merge.

## Version control

- Conventional commits. Commit often, each with a useful message.
- In Diego's personal repos, do not name an AI, model or tool in commits, PR text or comments. A git hook adds the `Co-Authored-By: Azogue bot` trailer.

## Testing

- In a Nix repo, run `nix flake check --no-build` before you say the work is done. Stage new files with `git add` first, because flakes only see tracked files.
- In a non-Nix repo, run tests in a rootless Podman container. Create the container file in the repo if none exists. Do not install packages with pip or npm on the host.
- If you cannot run the tests, say so and say why. Do not claim success.

## Documentation

- Docs go in `/docs`. Read existing docs first.
- Do not write fix histories into docs. Explain fixes in your reply.
- No emojis. Use Mermaid for diagrams.

## Writing style

- Never use em dashes. Do not use en dashes in their place. Use commas, colons, parentheses or separate sentences.
- For procedures and docs: one instruction per sentence, active voice, imperative steps, one word for one thing.

## Files

- Follow the layout the repo already has. If the repo breaks a standard practice, report it. Do not restructure it unasked.
- Keep each change small and reviewable. Do not fix unrelated things.
