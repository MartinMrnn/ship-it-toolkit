---
name: github-flow
description: Runs a repository with GitHub Issues, Projects and Milestones through gh. Use when the user says "setup", "capture", "start #N", "ship" or "release vX.Y.Z", or asks to note an idea in the backlog, start work on an issue, open the PR for the current work, or publish a version.
---

# github-flow

One repository = one GitHub Project, copied from the user's "Dev Template". Issues are the backlog. One milestone = one version (`vX.Y.Z`, also the tag name). One branch and one PR per issue.

## Rules

- Everything goes through `gh`. If a command fails, show the error and stop. No workarounds.
- Before any command except `setup`, read the "GitHub flow" section of the repository's `CLAUDE.md`: Project, Tests, Version. If it is missing, offer `setup` and stop.
- Statuses: `Backlog → Ready → Spec → Dev → Review → Done`.
  - GitHub sets `Backlog` (issue added), `Review` (PR linked) and `Done` (issue closed) on its own.
  - `Ready` and the milestone are the user's decisions.
  - You only set `Spec` and `Dev`.
- To set a field: `~/.claude/skills/github-flow/set-field.sh "<Project>" <issue-url> <Field> <Value>`.
- Never delete a label, an issue, a milestone or a project.
- **Always** end your reply with this block:

  ```
  ### Manual steps
  - …            (or "None.")
  ```

## setup

Run at the repository root, on a branch `github-flow-setup` created from the up-to-date default branch.

1. `gh auth status` must show the `project` scope. Otherwise stop and give `gh auth refresh -s project`.
2. Get `OWNER` and `REPO` with `gh repo view --json owner,name --jq '.owner.login+" "+.name'`, and `ME` with `gh api user --jq .login`.
3. **Labels**:
   - `gh label create chore --color c5def5 --description "Maintenance, tooling" --force`;
   - propose 2 or 3 area labels taken from the repository structure, have them approved, then run `gh label create <area> --color ededed --force` for each;
   - keep the existing labels.
4. **Project**:
   - look for it: `gh project list --owner $OWNER --format json --jq ".projects[]|select(.title==\"$REPO\")|.number"`;
   - if it does not exist:
     - `TEMPLATE=$(gh project list --owner $ME --format json --jq '.projects[]|select(.title=="Dev Template")|.number')`;
     - if `TEMPLATE` is empty, stop: the README explains how to copy the template;
     - otherwise `gh project copy $TEMPLATE --source-owner $ME --target-owner $OWNER --title "$REPO"`;
   - then `gh project link <n> --owner $OWNER --repo $OWNER/$REPO`;
   - add the open issues that already exist, which auto-add does not pick up: `gh issue list --state open --limit 500 --json url --jq '.[].url' | while read u; do gh project item-add <n> --owner $OWNER --url "$u" >/dev/null; done`.
5. **Repository**: `gh repo edit --delete-branch-on-merge`.
6. **Templates**: copy the skill's templates into the repository, without overwriting the files that already exist:
   - `mkdir -p .github/ISSUE_TEMPLATE && cp -n ~/.claude/skills/github-flow/templates/ISSUE_TEMPLATE/* .github/ISSUE_TEMPLATE/`;
   - `cp -n ~/.claude/skills/github-flow/templates/pull_request_template.md .github/`, unless the repository already has a PR template.
7. **`.gitignore`**: add the line `docs/superpowers/` if it is missing.
8. **CI**: if the repository has a test command, run it locally first. If it passes, create `.github/workflows/test.yml` from this model, adapted to the stack (for example, add the browser install if the tests need it):

   ```yaml
   name: test
   on:
     pull_request:
     push:
       branches: [main]
   jobs:
     test:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v4
         - uses: actions/setup-node@v4
           with:
             node-version: 22
             cache: npm
         - run: npm ci
         - run: npm test
   ```

   If there are no tests, there is no CI: note `Tests: none`.
9. **`CLAUDE.md`**: add this section (create the file if it is missing):

   ```markdown
   ## GitHub flow
   - Project: <REPO>
   - Tests: <command, or "none">
   - Version: <files where the version changes at release, or "none">

   Tracking goes through the github-flow skill: capture, start #N, ship, release vX.Y.Z.
   ```

10. Commit `Set up github-flow`, push, then `gh pr create --title "Set up github-flow" --body "Labels, project, templates, CI and the GitHub flow section of CLAUDE.md."`.

Manual steps:
- Turn on auto-add: https://github.com/users/<OWNER>/projects/<n>/workflows (for an organization, `orgs/<OWNER>`) → **Auto-add to project** → **Edit** → repository `<REPO>`, filter `is:issue is:open` → **Save and turn on workflow**.
- Review and merge the setup PR (give its link).

## capture <idea>

1. Pick the label: `enhancement` (idea), `bug`, `chore` or `documentation`, plus an area when it is obvious.
2. Write a short title and a body that keeps the user's words. No spec: it is an idea.
3. `gh issue create --title "<title>" --body "<body>" --label <label> --project "<Project>"`.
4. If the user gives a priority: `set-field.sh "<Project>" <url> Priority P1|P2|P3`.

Manual steps: prioritise, move to `Ready` and set a milestone whenever you want. Give the issue link.

## start #N

1. `gh issue view N --json title,body,labels,milestone,state,url`.
   - Closed issue: stop.
   - No milestone: say so, without blocking.
2. `git status --porcelain` must be empty. Otherwise stop and ask what to do with the changes in progress. Then `git switch <default branch> && git pull --prune`.
3. `set-field.sh "<Project>" <url> Status Spec`.
4. `gh issue develop N --name N-<3-4 words of the title in kebab-case> --checkout`. This links the branch to the issue.
5. Invoke `superpowers:brainstorming` with the issue (title and body) as the brief.
   - The spec and the plan go in `docs/superpowers/`, which git ignores: **do not commit them**. This rule overrides the brainstorming skill's commit step.
   - Without the superpowers plugin, agree on the approach with the user and write a short spec and plan in `docs/superpowers/` yourself.
   - If the work needs several PRs, create one sub-issue per PR: `gh issue create --title "…" --body "Part of #N" --label <label> --project "<Project>"`, then `gh api repos/{owner}/{repo}/issues/N/sub_issues -F sub_issue_id=$(gh api repos/{owner}/{repo}/issues/<M> --jq .id)`. Then continue with `start #<first sub-issue>`.
6. Once the plan is approved, before the first line of code: `set-field.sh "<Project>" <url> Status Dev`.

Manual steps: approve the spec, then the plan, when they are presented.

## ship

1. The issue number is the branch prefix (`N-…`). Otherwise ask for it.
2. Run the test command from `CLAUDE.md`. If it fails, stop.
3. `git push -u origin HEAD`.
4. Write the PR body from the template:
   - `Closes #N`;
   - **Decisions**: 3 to 6 points from the local spec (`docs/superpowers/specs/`): what is done, what is left out and why;
   - **Tests**: the command run and its result.
5. `gh pr create --title "<issue title>" --body-file <temporary file>`, with `--milestone "<issue milestone>"` when it has one.
6. After 10 seconds, check that the issue is in `Review` (`gh project item-list`). Otherwise set it with `set-field.sh`.

Manual steps: review and merge the PR (give its link). The issue will move to `Done` on its own.

## release vX.Y.Z

If the tag already exists (`gh release view vX.Y.Z`), stop: the version is published.
If a merged PR is called "Release vX.Y.Z" (`gh pr list --state merged --limit 100 --json number,title --jq '.[]|select(.title=="Release vX.Y.Z")|.number'`), go to phase 2. Otherwise start with phase 1. Do not use `--search` here: the search index lags a few seconds behind a merge.

**Phase 1: prepare**

1. `gh api "repos/{owner}/{repo}/milestones?state=open" --jq '.[]|select(.title=="vX.Y.Z")|"\(.number) \(.open_issues)"'`.
   - No milestone: stop.
   - Issues still open: list them (`gh issue list --milestone vX.Y.Z --state open`) and stop.
2. `gh issue list --milestone vX.Y.Z --state closed --limit 200 --json number,title,labels`.
3. Create the branch `release-vX.Y.Z` from the up-to-date default branch.
4. Set `X.Y.Z` in every file listed on the "Version" line of `CLAUDE.md`.
5. At the top of `CHANGELOG.md` (create it if it is missing), write the version entry in the format of the previous entries. One line per closed issue, followed by `(#N)`: features (`enhancement`) first, then fixes (`bug`), then the rest.
6. Run the tests, commit `Release vX.Y.Z`, push, then `gh pr create --title "Release vX.Y.Z" --body "<the CHANGELOG entry>" --milestone vX.Y.Z`.

Manual steps: merge the release PR, then run `release vX.Y.Z` again.

**Phase 2: publish**

1. `git switch <default branch> && git pull`.
2. `gh release create vX.Y.Z --target <default branch> --title "vX.Y.Z" --notes "<the CHANGELOG entry>"`. This also creates the tag.
3. `gh api -X PATCH repos/{owner}/{repo}/milestones/<number> -f state=closed`.

Manual steps: none.
