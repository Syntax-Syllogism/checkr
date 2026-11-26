/**
 * Turn ```mermaid fenced blocks into <pre class="mermaid"> elements so that
 * Starlight's code-block renderer leaves them alone. The diagrams are drawn in
 * the browser by mermaid-client.mjs.
 */
export function remarkMermaid() {
  return (tree) => walk(tree);
}

function escapeHtml(text) {
  return text
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}

function walk(node) {
  const children = node.children;
  if (!children) return;
  for (let i = 0; i < children.length; i++) {
    const child = children[i];
    if (child.type === "code" && child.lang === "mermaid") {
      children[i] = {
        type: "html",
        value: `<pre class="mermaid" data-mermaid-source>${escapeHtml(child.value)}</pre>`
      };
    } else {
      walk(child);
    }
  }
}
