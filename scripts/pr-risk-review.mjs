#!/usr/bin/env node

import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const DEFAULT_POLICY = path.join(ROOT, ".github/pr-risk-policy.json");
const COMMENT_MARKER = "<!-- burner-list-pr-risk-review -->";

function matches(pattern, filename) {
  const escaped = pattern
    .replace(/[.+^${}()|[\]\\]/g, "\\$&")
    .replace(/\*\*\//g, "\u0001")
    .replace(/\*\*/g, "\u0000")
    .replace(/\*/g, "[^/]*")
    .replace(/\u0000/g, ".*")
    .replace(/\u0001/g, "(?:.*/)?");
  return new RegExp(`^${escaped}$`, "i").test(filename);
}

function anyMatch(patterns, filename) {
  return patterns.some((pattern) => matches(pattern, filename));
}

export function scorePullRequest(files, policy, pull = {}) {
  const changedFiles = Number(pull.changed_files ?? files.length);
  const additions = Number(pull.additions ?? files.reduce((n, f) => n + (f.additions || 0), 0));
  const deletions = Number(pull.deletions ?? files.reduce((n, f) => n + (f.deletions || 0), 0));
  const changes = additions + deletions;
  const names = files.map((file) => file.filename);
  const sensitive = names.filter((name) => anyMatch(policy.alwaysHumanReview, name));
  const operations = names.filter((name) => anyMatch(policy.operationsFiles, name));
  const data = names.filter((name) => anyMatch(policy.dataFiles, name));
  const tests = names.filter((name) => anyMatch(policy.testFiles, name));
  const docsOnly = names.length > 0 && names.every((name) => anyMatch(policy.docsOnlyFiles, name));
  const generated = names.filter((name) => anyMatch(policy.generatedFiles, name));
  const codeFiles = names.filter((name) => /\.(?:js|mjs|ts|tsx|swift|sql|html|css)$/i.test(name));
  const incompleteDiff = changedFiles > files.length || files.some((file) => !file.patch && file.status !== "removed");

  let surface = changedFiles <= 2 && changes <= 80 ? 3
    : changedFiles <= 6 && changes <= 300 ? 8
      : changedFiles <= 15 && changes <= 800 ? 14 : 20;
  if (docsOnly) surface = Math.min(surface, 5);

  const components = {
    changeSurface: surface,
    reversibility: data.length ? 15 : operations.length ? 10 : codeFiles.length ? 4 : 1,
    dataAndSecurity: sensitive.length ? 25 : data.length ? 16 : 0,
    operations: operations.length ? 15 : 0,
    verificationGap: codeFiles.length > 0 && tests.length === 0 ? 20 : 0,
    uncertainty: incompleteDiff ? 10 : generated.length > 0 && generated.length === names.length ? 5 : 0
  };

  let score = Object.values(components).reduce((sum, value) => sum + value, 0);
  if (sensitive.length) score = Math.max(score, policy.thresholds.mediumMaximum + 1);
  score = Math.min(score, 100);
  const level = score <= policy.thresholds.lowMaximum ? "low"
    : score <= policy.thresholds.mediumMaximum ? "medium" : "high";
  const blockers = [];
  if (pull.draft) blockers.push("The pull request is a draft.");
  if (pull.mergeable === false) blockers.push("The pull request has merge conflicts.");
  if (sensitive.length) blockers.push(`Human-review paths changed: ${sensitive.slice(0, 5).join(", ")}.`);
  if (incompleteDiff) blockers.push("The complete diff was not available for automated inspection.");

  return { score, level, components, blockers, sensitive, stats: { changedFiles, additions, deletions } };
}

function render(result, pull) {
  const rows = Object.entries(result.components)
    .map(([name, value]) => `| ${name.replace(/([A-Z])/g, " $1").toLowerCase()} | ${value} |`)
    .join("\n");
  const decision = result.level === "low" && result.blockers.length === 0
    ? "Eligible for automated approval"
    : "Human review required";
  const blockers = result.blockers.length ? `\n\n**Approval blockers**\n${result.blockers.map((item) => `- ${item}`).join("\n")}` : "";
  return `${COMMENT_MARKER}\n## PR risk review: ${result.level.toUpperCase()} (${result.score}/100)\n\n**Decision:** ${decision}\n\n| Signal | Points |\n| --- | ---: |\n${rows}\n\nChanged ${result.stats.changedFiles} files (+${result.stats.additions}/-${result.stats.deletions}).${blockers}\n\n<sub>Policy v1 · evaluated commit \`${pull.head.sha.slice(0, 12)}\` · this review is advisory and does not merge code.</sub>`;
}

async function github(token, endpoint, options = {}) {
  const response = await fetch(`https://api.github.com${endpoint}`, {
    ...options,
    headers: {
      Accept: "application/vnd.github+json",
      Authorization: `Bearer ${token}`,
      "X-GitHub-Api-Version": "2022-11-28",
      "User-Agent": "burner-list-pr-risk-review",
      ...options.headers
    }
  });
  if (!response.ok) throw new Error(`${options.method || "GET"} ${endpoint}: ${response.status} ${await response.text()}`);
  return response.status === 204 ? null : response.json();
}

async function upsertComment(token, repo, prNumber, body) {
  const comments = await github(token, `/repos/${repo}/issues/${prNumber}/comments?per_page=100`);
  const previous = comments.find((comment) => comment.body?.includes(COMMENT_MARKER) && comment.user?.type === "Bot");
  if (previous) return github(token, `/repos/${repo}/issues/comments/${previous.id}`, { method: "PATCH", body: JSON.stringify({ body }) });
  return github(token, `/repos/${repo}/issues/${prNumber}/comments`, { method: "POST", body: JSON.stringify({ body }) });
}

async function setRiskLabel(token, repo, prNumber, level) {
  const labels = await github(token, `/repos/${repo}/issues/${prNumber}/labels`);
  for (const label of labels.filter((item) => /^risk: (low|medium|high)$/.test(item.name) && item.name !== `risk: ${level}`)) {
    await github(token, `/repos/${repo}/issues/${prNumber}/labels/${encodeURIComponent(label.name)}`, { method: "DELETE" });
  }
  try {
    await github(token, `/repos/${repo}/issues/${prNumber}/labels`, { method: "POST", body: JSON.stringify({ labels: [`risk: ${level}`] }) });
  } catch (error) {
    if (!String(error).includes("422")) throw error;
    console.warn(`Risk label does not exist; skipping label: ${error.message}`);
  }
}

async function main() {
  const args = Object.fromEntries(process.argv.slice(2).map((arg) => {
    const [key, ...value] = arg.replace(/^--/, "").split("=");
    return [key, value.join("=") || true];
  }));
  const repo = args.repo || process.env.GITHUB_REPOSITORY;
  const token = process.env.GITHUB_TOKEN;
  let prNumber = Number(args.pr === true ? 0 : args.pr || process.env.PR_NUMBER);
  if (!repo || !token) throw new Error("GITHUB_TOKEN and repository are required.");
  const event = process.env.GITHUB_EVENT_PATH
    ? JSON.parse(await fs.readFile(process.env.GITHUB_EVENT_PATH, "utf8"))
    : {};
  if (!prNumber) {
    prNumber = Number(event.workflow_run?.pull_requests?.[0]?.number);
    if (!prNumber && event.workflow_run?.head_sha) {
      const candidates = await github(token, `/repos/${repo}/commits/${event.workflow_run.head_sha}/pulls`);
      prNumber = Number(candidates.find((candidate) => candidate.state === "open")?.number);
    }
  }
  if (!prNumber) throw new Error("Could not resolve a pull request number for this workflow run.");

  const policy = JSON.parse(await fs.readFile(args.policy || DEFAULT_POLICY, "utf8"));
  const pull = await github(token, `/repos/${repo}/pulls/${prNumber}`);
  const files = [];
  for (let page = 1; page <= Math.ceil(pull.changed_files / 100); page += 1) {
    files.push(...await github(token, `/repos/${repo}/pulls/${prNumber}/files?per_page=100&page=${page}`));
  }
  const result = scorePullRequest(files, policy, pull);
  if (event.workflow_run?.head_sha && event.workflow_run.head_sha !== pull.head.sha) {
    result.blockers.push("Successful checks belong to an older commit; waiting for checks on the current head.");
  }
  await upsertComment(token, repo, prNumber, render(result, pull));
  await setRiskLabel(token, repo, prNumber, result.level);

  if (result.level === "low" && result.blockers.length === 0) {
    try {
      await github(token, `/repos/${repo}/pulls/${prNumber}/reviews`, {
        method: "POST",
        body: JSON.stringify({ event: "APPROVE", body: `Automated low-risk approval (${result.score}/100) for ${pull.head.sha.slice(0, 12)}.` })
      });
      console.log(`Approved PR #${prNumber}: low risk (${result.score}/100).`);
    } catch (error) {
      console.warn(`Approval was not permitted by repository settings: ${error.message}`);
    }
  } else {
    console.log(`PR #${prNumber} requires human review: ${result.level} risk (${result.score}/100).`);
  }
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}
