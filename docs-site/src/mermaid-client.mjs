import mermaid from "mermaid";
import "./mermaid.css";

const root = document.documentElement;
const nodes = [
  ...document.querySelectorAll("pre.mermaid[data-mermaid-source]")
];

if (nodes.length > 0) {
  for (const node of nodes) node.dataset.mermaidSource = node.textContent;

  const isDark = () => root.dataset.theme !== "light";
  let seq = 0;

  const render = async () => {
    mermaid.initialize({
      startOnLoad: false,
      securityLevel: "strict",
      theme: isDark() ? "dark" : "default",
      fontFamily: "system-ui, sans-serif"
    });
    for (const node of nodes) {
      try {
        const { svg } = await mermaid.render(
          `mermaid-${seq++}`,
          node.dataset.mermaidSource
        );
        node.innerHTML = svg;
        node.dataset.processed = "true";
      } catch (error) {
        console.error("Mermaid render failed", error);
      }
    }
  };

  render();
  let last = isDark();
  new MutationObserver(() => {
    if (isDark() !== last) {
      last = isDark();
      render();
    }
  }).observe(root, { attributes: true, attributeFilter: ["data-theme"] });
}
