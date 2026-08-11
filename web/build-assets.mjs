// Generates everything the playground needs into vendor/:
//
//   ruby-wasm.umd.js   the ruby.wasm browser runtime (self-contained UMD)
//   ruby+stdlib.wasm   CRuby 3.4 + stdlib
//   lib-bundle.json    every .rb in the Jade gem, seeded into the WASI fs
//
// Run after `npm install`, and again whenever the compiler changes:
//   npm run assets
//
// JADE_LIB points at the Jade checkout to bundle. Defaults to this repo's lib.

import { readFile, readdir, writeFile, mkdir, copyFile } from 'node:fs/promises';
import { join, relative, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const WEB = dirname(fileURLToPath(import.meta.url));
const LIB = process.env.JADE_LIB || join(WEB, '..', 'lib');
const VENDOR = join(WEB, 'vendor');

async function walk(dir) {
  const out = [];
  for (const entry of await readdir(dir, { withFileTypes: true })) {
    const path = join(dir, entry.name);
    if (entry.isDirectory()) out.push(...(await walk(path)));
    else if (entry.name.endsWith('.rb')) out.push(path);
  }
  return out;
}

await mkdir(VENDOR, { recursive: true });

const paths = await walk(LIB);
const bundle = {};
for (const path of paths) bundle[relative(LIB, path)] = await readFile(path, 'utf8');

const json = JSON.stringify(bundle);
await writeFile(join(VENDOR, 'lib-bundle.json'), json);

await copyFile(
  join(WEB, 'node_modules/@ruby/wasm-wasi/dist/browser.umd.js'),
  join(VENDOR, 'ruby-wasm.umd.js'),
);
await copyFile(
  join(WEB, 'node_modules/@ruby/3.4-wasm-wasi/dist/ruby+stdlib.wasm'),
  join(VENDOR, 'ruby+stdlib.wasm'),
);

console.log(`lib-bundle.json  ${paths.length} files, ${(json.length / 1048576).toFixed(2)} MB`);
console.log(`vendored runtime + wasm from ${LIB}`);
