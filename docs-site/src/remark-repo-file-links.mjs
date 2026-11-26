import path from "node:path";

/**
 * Point relative links at files that are not docs pages (root files such as
 * README.md or LICENSE, and evidence data such as summary.json) at the file on
 * GitHub. Links to Markdown pages inside docs/ are left for
 * remarkRelativeMdLinks to map to site routes.
 */
export function remarkRepoFileLinks({
  docsRoot,
  publicRepo,
  branch = "release"
}) {
  const repoRoot = path.dirname(docsRoot);
  return (tree, file) => {
    const source = file.path ?? file.history?.[0];
    if (!source) return;
    walk(tree, (node) => {
      const url = node.url;
      if (!url || /^([a-z][a-z0-9+.-]*:|#|\/)/i.test(url)) return;
      const [target, hash = ""] = url.split("#");
      if (!target) return;
      const resolved = path.resolve(path.dirname(source), target);
      const inDocs = !path.relative(docsRoot, resolved).startsWith("..");
      if (inDocs && resolved.endsWith(".md")) return;
      const repoPath = path
        .relative(repoRoot, resolved)
        .split(path.sep)
        .join("/");
      if (repoPath.startsWith("..")) return;
      node.url = `https://github.com/${publicRepo}/blob/${branch}/${repoPath}${hash ? `#${hash}` : ""}`;
    });
  };
}

function walk(node, fn) {
  if (node.type === "link") fn(node);
  for (const child of node.children ?? []) walk(child, fn);
}
