// Checks that every image the docs reference exists, that every file in
// docs/images is referenced, and that the admin guide screenshots match
// scripts/docs/shots.json one for one.
import assert from "node:assert/strict";
import { existsSync, readFileSync, readdirSync } from "node:fs";
import { dirname, join, relative, resolve } from "node:path";
import test from "node:test";

const root = join(import.meta.dirname, "..", ".."),
  docsDir = join(root, "docs"),
  imageDir = join(docsDir, "images"),
  shotDir = join(imageDir, "admin-guide");

function walk(dir, keep) {
  return readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const path = join(dir, entry.name);
    if (entry.isDirectory()) return walk(path, keep);
    return keep(entry.name) ? [path] : [];
  });
}

const pages = walk(docsDir, (name) => name.endsWith(".md")),
  images = existsSync(imageDir) ? walk(imageDir, () => true) : [],
  // Absolute image path -> pages that reference it.
  referenced = new Map(),
  external = /^(?:[a-z]+:|\/\/)/i;

for (const page of pages) {
  const text = readFileSync(page, "utf8");
  for (const match of text.matchAll(/!\[[^\]]*\]\(\s*<?([^)\s>]+)>?/g)) {
    if (external.test(match[1])) continue;
    const target = resolve(dirname(page), match[1].split("#")[0]);
    referenced.set(target, [...(referenced.get(target) ?? []), page]);
  }
}

const rel = (path) => relative(root, path);

test("every image the docs reference exists", () => {
  const missing = [...referenced]
    .filter(([image]) => !existsSync(image))
    .map(([image, from]) => `${rel(image)} (from ${from.map(rel).join(", ")})`);
  assert.deepEqual(missing, []);
});

test("every file in docs/images is referenced by a page", () => {
  const orphans = images.filter((image) => !referenced.has(image)).map(rel);
  assert.deepEqual(orphans, []);
});

test("every image reference has alt text", () => {
  for (const page of pages) {
    assert.doesNotMatch(
      readFileSync(page, "utf8"),
      /!\[\s*\]\(/,
      `${rel(page)} has an image without alt text`
    );
  }
});

test("admin guide screenshots match scripts/docs/shots.json", () => {
  const ids = JSON.parse(
    readFileSync(join(root, "scripts", "docs", "shots.json"), "utf8")
  )
    .shots.map((shot) => `${shot.id}.png`)
    .sort();
  const used = [...referenced.keys()]
    .filter((image) => dirname(image) === shotDir)
    .map((image) => relative(shotDir, image))
    .sort();
  assert.deepEqual(used, ids);
});
