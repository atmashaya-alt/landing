#!/usr/bin/env node
/**
 * Zero-dependency verification script for calc-core.js.
 *
 * Runs every vector in calc-core.test-vectors.json against the calc-core.js
 * that lives alongside this script, and fails loudly on any mismatch.
 *
 * This is the actual gate before any platform's migration commits — there is
 * no CI in this codebase, so this is run manually. It's also copied into
 * every vendored platform (see sync.ps1) so each platform can verify its own
 * copy hasn't drifted from the canonical source.
 *
 * Usage: node verify.mjs
 */
import { readFileSync } from 'node:fs';
import { fileURLToPath, pathToFileURL } from 'node:url';
import path from 'node:path';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const calcCore = await import(pathToFileURL(path.join(__dirname, 'calc-core.js')));
const vectors = JSON.parse(readFileSync(path.join(__dirname, 'calc-core.test-vectors.json'), 'utf8'));

let pass = 0;
let fail = 0;

function deepAlmostEqual(actual, expected, tolerance = 0.01) {
  if (typeof expected === 'number' && typeof actual === 'number') {
    if (Number.isNaN(expected) && Number.isNaN(actual)) return true;
    return Math.abs(actual - expected) <= tolerance;
  }
  if (typeof expected === 'string') return actual === expected;
  if (expected && typeof expected === 'object') {
    return Object.keys(expected).every(k => deepAlmostEqual(actual?.[k], expected[k], tolerance));
  }
  return actual === expected;
}

for (const vector of vectors) {
  const fn = calcCore[vector.fn];
  if (typeof fn !== 'function') {
    console.error(`✗ FAIL  ${vector.description}\n        calc-core.js has no export "${vector.fn}"`);
    fail++;
    continue;
  }

  let actual;
  try {
    // Vectors record inputs as either a single object arg (most calculators)
    // or need positional spreading — detect by checking the source fn arity
    // against the inputs shape. All current calculators here take a single
    // params object EXCEPT pvFiniteAnnuity/calcDreadDisease/etc which are
    // positional — call with Object.values() in declared key order for those.
    const isPositional = fn.length > 1;
    actual = isPositional ? fn(...Object.values(vector.inputs)) : fn(vector.inputs);
  } catch (e) {
    console.error(`✗ FAIL  ${vector.description}\n        threw: ${e.message}`);
    fail++;
    continue;
  }

  // Ignore the free-text "motivation" field in comparisons — only numbers matter for drift detection.
  const expectedNumeric = { ...vector.result };
  delete expectedNumeric.motivation;
  const actualNumeric = actual && typeof actual === 'object' ? { ...actual } : actual;
  if (actualNumeric && typeof actualNumeric === 'object') delete actualNumeric.motivation;

  if (deepAlmostEqual(actualNumeric, expectedNumeric)) {
    console.log(`✓ PASS  ${vector.description}`);
    pass++;
  } else {
    console.error(`✗ FAIL  ${vector.description}`);
    console.error(`        expected: ${JSON.stringify(expectedNumeric)}`);
    console.error(`        actual:   ${JSON.stringify(actualNumeric)}`);
    fail++;
  }
}

console.log(`\n${pass} passed, ${fail} failed (${vectors.length} total)`);
if (fail > 0) process.exit(1);
