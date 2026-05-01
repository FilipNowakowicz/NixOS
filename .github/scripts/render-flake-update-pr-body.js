const fs = require("node:fs");
const { execFileSync } = require("node:child_process");

function readJsonFile(path) {
  return JSON.parse(fs.readFileSync(path, "utf8"));
}

function readPreviousLockFromGit() {
  const json = execFileSync("git", ["show", "HEAD:flake.lock"], {
    encoding: "utf8",
  });
  return JSON.parse(json);
}

function resolveInputTarget(lock, startNodeName, inputRef) {
  if (typeof inputRef === "string") {
    return inputRef;
  }

  let currentNodeName = startNodeName;
  for (const segment of inputRef) {
    const currentNode = lock.nodes[currentNodeName];
    if (!currentNode?.inputs?.[segment]) {
      throw new Error(
        `Unable to resolve input path ${inputRef.join(".")} from ${startNodeName}`,
      );
    }
    currentNodeName = resolveInputTarget(
      lock,
      currentNodeName,
      currentNode.inputs[segment],
    );
  }

  return currentNodeName;
}

function collectDirectInputs(lock) {
  const rootInputs = lock.nodes.root?.inputs ?? {};
  const directInputs = new Map();

  for (const [inputName, inputRef] of Object.entries(rootInputs)) {
    directInputs.set(inputName, resolveInputTarget(lock, "root", inputRef));
  }

  return directInputs;
}

function formatDate(epochSeconds) {
  if (typeof epochSeconds !== "number") {
    return null;
  }

  return new Date(epochSeconds * 1000).toISOString().slice(0, 10);
}

function shorten(value, length = 7) {
  if (typeof value !== "string") {
    return null;
  }

  return value.slice(0, length);
}

function describeSource(node) {
  const locked = node?.locked;
  if (!locked) {
    return "unknown source";
  }

  if (locked.type === "github") {
    return `${locked.owner}/${locked.repo}`;
  }

  if (locked.type === "git") {
    return locked.url;
  }

  return locked.type ?? "unknown source";
}

function compareUrl(oldNode, newNode) {
  const oldLocked = oldNode?.locked;
  const newLocked = newNode?.locked;
  if (!oldLocked || !newLocked) {
    return null;
  }

  if (
    oldLocked.type === "github" &&
    newLocked.type === "github" &&
    oldLocked.owner === newLocked.owner &&
    oldLocked.repo === newLocked.repo &&
    oldLocked.rev &&
    newLocked.rev &&
    oldLocked.rev !== newLocked.rev
  ) {
    return `https://github.com/${newLocked.owner}/${newLocked.repo}/compare/${oldLocked.rev}...${newLocked.rev}`;
  }

  return null;
}

function describeChange(oldNode, newNode) {
  if (!oldNode?.locked && newNode?.locked) {
    const rev = shorten(newNode.locked.rev) ?? "new lock";
    const date = formatDate(newNode.locked.lastModified);
    return date ? `added at \`${rev}\` on ${date}` : `added at \`${rev}\``;
  }

  if (oldNode?.locked && !newNode?.locked) {
    const rev = shorten(oldNode.locked.rev) ?? "old lock";
    const date = formatDate(oldNode.locked.lastModified);
    return date
      ? `removed (was \`${rev}\` from ${date})`
      : `removed (was \`${rev}\`)`;
  }

  const oldLocked = oldNode.locked;
  const newLocked = newNode.locked;
  const oldRev = shorten(oldLocked.rev);
  const newRev = shorten(newLocked.rev);
  const oldDate = formatDate(oldLocked.lastModified);
  const newDate = formatDate(newLocked.lastModified);
  const link = compareUrl(oldNode, newNode);

  if (oldRev && newRev && oldRev !== newRev) {
    const revText = link
      ? `[\`${oldRev}\` -> \`${newRev}\`](${link})`
      : `\`${oldRev}\` -> \`${newRev}\``;
    if (oldDate && newDate && oldDate !== newDate) {
      return `${revText} (${oldDate} -> ${newDate})`;
    }
    return revText;
  }

  if (oldLocked.narHash !== newLocked.narHash) {
    return "`narHash` changed";
  }

  if ((oldLocked.ref ?? null) !== (newLocked.ref ?? null)) {
    return `ref changed from \`${oldLocked.ref ?? "unknown"}\` to \`${newLocked.ref ?? "unknown"}\``;
  }

  return "lock metadata changed";
}

function summarizeChanges(oldLock, newLock) {
  const directInputs = new Map([
    ...collectDirectInputs(oldLock).entries(),
    ...collectDirectInputs(newLock).entries(),
  ]);
  const directNodeNames = new Set(directInputs.values());
  const changes = [];
  const allNodeNames = new Set([
    ...Object.keys(oldLock.nodes ?? {}),
    ...Object.keys(newLock.nodes ?? {}),
  ]);

  for (const nodeName of allNodeNames) {
    if (nodeName === "root") {
      continue;
    }

    const oldNode = oldLock.nodes?.[nodeName];
    const newNode = newLock.nodes?.[nodeName];
    const oldLocked = oldNode?.locked;
    const newLocked = newNode?.locked;

    if (!oldLocked && !newLocked) {
      continue;
    }

    if (
      JSON.stringify(oldLocked ?? null) === JSON.stringify(newLocked ?? null)
    ) {
      continue;
    }

    const directInputName =
      [...directInputs.entries()].find(
        ([, target]) => target === nodeName,
      )?.[0] ?? null;

    changes.push({
      name: directInputName ?? nodeName,
      nodeName,
      source: describeSource(newNode ?? oldNode),
      change: describeChange(oldNode, newNode),
      isDirect: directNodeNames.has(nodeName),
    });
  }

  changes.sort((a, b) => a.name.localeCompare(b.name));
  return changes;
}

function renderSection(title, items) {
  if (items.length === 0) {
    return "";
  }

  const lines = [`## ${title}`];
  for (const item of items) {
    lines.push(`- \`${item.name}\` (${item.source}): ${item.change}`);
  }
  return lines.join("\n");
}

function renderBody(oldLock, newLock) {
  const changes = summarizeChanges(oldLock, newLock);
  const directChanges = changes.filter((change) => change.isDirect);
  const transitiveChanges = changes.filter((change) => !change.isDirect);

  const sections = [
    "Automated weekly update of `flake.lock`.",
    "",
    "This PR auto-merges if the required merge gate passes.",
  ];

  if (changes.length === 0) {
    sections.push("", "No lockfile updates were detected.");
    return `${sections.join("\n")}\n`;
  }

  if (directChanges.length > 0) {
    sections.push(
      "",
      renderSection(
        `Updated direct inputs (${directChanges.length})`,
        directChanges,
      ),
    );
  } else {
    sections.push(
      "",
      "## Updated direct inputs",
      "",
      "No direct flake inputs changed.",
    );
  }

  if (transitiveChanges.length > 0) {
    const lines = [
      `<details>`,
      `<summary>Additional transitive lockfile updates (${transitiveChanges.length})</summary>`,
      "",
    ];
    for (const item of transitiveChanges) {
      lines.push(`- \`${item.name}\` (${item.source}): ${item.change}`);
    }
    lines.push("", "</details>");
    sections.push("", lines.join("\n"));
  }

  return `${sections.join("\n")}\n`;
}

function main() {
  const [, , oldPath, newPath = "flake.lock"] = process.argv;
  const oldLock = oldPath ? readJsonFile(oldPath) : readPreviousLockFromGit();
  const newLock = readJsonFile(newPath);
  process.stdout.write(renderBody(oldLock, newLock));
}

main();
