import assert from "node:assert/strict";
import fs from "node:fs/promises";
import test from "node:test";
import { scorePullRequest } from "./pr-risk-review.mjs";

const policy = JSON.parse(await fs.readFile(new URL("../.github/pr-risk-policy.json", import.meta.url)));

const file = (filename, additions = 5, deletions = 1, patch = "@@") => ({ filename, additions, deletions, patch, status: "modified" });

test("docs-only change is low risk", () => {
  const result = scorePullRequest([file("README.md"), file("docs/IOS_AUDIT.md")], policy, { changed_files: 2, additions: 5, deletions: 1, mergeable: true });
  assert.equal(result.level, "low");
  assert.deepEqual(result.blockers, []);
});

test("migration always requires high-risk human review", () => {
  const result = scorePullRequest([file("supabase/migrations/20260811_change.sql", 30)], policy, { changed_files: 1, additions: 30, deletions: 0, mergeable: true });
  assert.equal(result.level, "high");
  assert.match(result.blockers.join(" "), /Human-review paths/);
});

test("merge conflicts block an otherwise low-risk approval", () => {
  const result = scorePullRequest([file("README.md")], policy, { changed_files: 1, additions: 5, deletions: 1, mergeable: false });
  assert.equal(result.level, "low");
  assert.match(result.blockers.join(" "), /merge conflicts/);
});

test("application code without tests cannot be low risk", () => {
  const result = scorePullRequest([file("index.html", 12, 2)], policy, { changed_files: 1, additions: 12, deletions: 2, mergeable: true });
  assert.notEqual(result.level, "low");
});

test("large application change escalates", () => {
  const files = Array.from({ length: 18 }, (_, index) => file(`ios/BurnerList/Features/View${index}.swift`, 60, 5));
  const result = scorePullRequest(files, policy, { changed_files: 18, additions: 1080, deletions: 90, mergeable: true });
  assert.notEqual(result.level, "low");
});
