#!/usr/bin/env node
// Renders every card in a cards config file to a PNG via headless Chrome.
//
// Prerequisite: hero-card-template.html must be served over HTTP (not
// file://) since it uses ES modules. From this directory:
//   python -m http.server 8765
// (leave that running in one terminal, then run this script in another)
//
// Usage: node generate-cards.mjs [cards-file.json] [output-subdir]
//   node generate-cards.mjs                              # cards.json -> output/
//   node generate-cards.mjs cards-adviser.json output-adviser
import { readFileSync, mkdirSync, writeFileSync, existsSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const TEMPLATE_URL = 'http://localhost:8765/hero-card-template.html';
const SIZE = { w: 1080, h: 1080 };

const CHROME_CANDIDATES = [
  'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
  'C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe',
  'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe',
  'C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe',
];
const CHROME = CHROME_CANDIDATES.find(existsSync);
if (!CHROME) {
  console.error('No Chrome or Edge install found in the usual locations. Edit CHROME_CANDIDATES in this script.');
  process.exit(1);
}

const cardsFile = process.argv[2] || 'cards.json';
const outSubdir = process.argv[3] || 'output';
const outDir = path.join(__dirname, outSubdir);
mkdirSync(outDir, { recursive: true });

const cards = JSON.parse(readFileSync(path.join(__dirname, cardsFile), 'utf8'));

const manifest = [];
for (const card of cards) {
  const cfgEncoded = encodeURIComponent(JSON.stringify(card.cfg));
  const url = `${TEMPLATE_URL}?cfg=${cfgEncoded}`;
  const outPath = path.join(outDir, `${card.id}.png`);
  execFileSync(CHROME, [
    '--headless', '--disable-gpu', '--hide-scrollbars',
    '--force-device-scale-factor=1',
    `--window-size=${SIZE.w},${SIZE.h}`,
    `--screenshot=${outPath}`,
    url,
  ], { stdio: 'pipe' });
  manifest.push({ id: card.id, category: card.category, file: `${card.id}.png`, destination: card.destination });
  console.log(`rendered ${card.id}.png -> ${card.destination}`);
}

writeFileSync(path.join(outDir, 'manifest.json'), JSON.stringify(manifest, null, 2));
console.log(`\nDone: ${cards.length} cards in ${outDir}`);
