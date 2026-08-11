# Automated PR risk review

Burner List uses a deterministic, auditable risk score after `PR Checks` succeeds. The reviewer reads pull-request metadata and diffs through the GitHub API; it does not execute pull-request code with a privileged token.

Scores from 0–24 are low risk, 25–64 are medium risk, and 65–100 are high risk. The score considers change surface, reversibility, data/security impact, operational impact, verification gaps, and incomplete diffs. Sensitive paths such as authentication, migrations, deployment, and workflow configuration always require human review.

Low-risk changes with no blocker receive an approval attempt. Medium/high-risk changes, drafts, merge conflicts, sensitive paths, and incomplete diffs remain for a human. The automation never merges a pull request. GitHub may reject bot approvals unless repository settings permit Actions to approve pull requests; the risk comment and label are still produced. For forked pull requests where the workflow event omits the PR number, the reviewer resolves the open PR from the checked commit SHA.

Edit `.github/pr-risk-policy.json` to tune repository-specific paths and thresholds. Changes to the policy or either workflow are themselves human-review-only.

Run the policy tests locally with:

```bash
node --test scripts/pr-risk-review.test.mjs
```

Repository setup:

1. Create labels named `risk: low`, `risk: medium`, and `risk: high` (optional; review continues if they are absent).
2. In Actions settings, enable “Allow GitHub Actions to create and approve pull requests” if automated approvals are desired.
3. Add `PR Checks` as a required status check in the `main` branch ruleset.
4. Keep a human approval requirement for medium/high-risk and protected paths. Confirm the policy with the security/compliance owner before treating bot approval as a control.
