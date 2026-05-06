import { writeFile } from "node:fs/promises";
import process from "node:process";
import { Agent, CursorAgentError } from "@cursor/sdk";

function utcDateTag() {
  const now = new Date();
  const y = now.getUTCFullYear();
  const m = String(now.getUTCMonth() + 1).padStart(2, "0");
  const d = String(now.getUTCDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

async function main() {
  const apiKey = process.env.CURSOR_API_KEY;
  if (!apiKey) {
    throw new Error("Missing CURSOR_API_KEY environment variable.");
  }

  const prompt = `
You are running an unattended nightly bug scan for this Flutter repository.

Goals:
1) Find likely bugs, regressions, and runtime risks (not style nitpicks).
2) Prioritize findings by severity (high -> medium -> low).
3) Include concrete file paths and brief rationale.
4) Suggest minimal fixes and tests for each finding.

Instructions:
- Do NOT modify files.
- You may run commands/tests as needed.
- Keep output concise and actionable.
- If no issues are found, clearly say so and list any test gaps.

Output format (markdown):
## Nightly Bug Scan
### Findings
- [Severity] ...
### Suggested Fixes
- ...
### Test Gaps / Residual Risk
- ...
`;

  try {
    const result = await Agent.prompt(prompt, {
      apiKey,
      model: { id: "composer-2" },
      local: { cwd: process.cwd() },
    });

    if (result.status !== "finished") {
      const content = `# Nightly Bug Scan (${utcDateTag()})

Scan did not finish successfully.

- Status: \`${result.status}\`
- Result ID: \`${result.id}\`
`;
      await writeFile("nightly-bug-scan.md", content, "utf8");
      process.exitCode = 2;
      return;
    }

    const body = typeof result.result === "string" ? result.result : String(result.result ?? "");
    const content = `# Nightly Bug Scan (${utcDateTag()})

${body}
`;
    await writeFile("nightly-bug-scan.md", content, "utf8");
  } catch (err) {
    if (err instanceof CursorAgentError) {
      const content = `# Nightly Bug Scan (${utcDateTag()})

Failed to start Cursor agent.

- Message: ${err.message}
- Retryable: ${String(err.isRetryable)}
`;
      await writeFile("nightly-bug-scan.md", content, "utf8");
      process.exitCode = 1;
      return;
    }
    throw err;
  }
}

await main();
