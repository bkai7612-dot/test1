// Headless smoke test: runs the real server + client scripts against a
// mocked Roblox engine (tests/mock.luau) inside a Luau VM, then plays
// through shopping, Robux receipts, a test drive and a race on every map.
//
//   cd tests && npm install && npm test
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const SRC = path.join(HERE, '..', 'src');

// luau-web ships a fixed 17 MB wasm heap, too small for a full track.
// Raise the initial memory (idempotent) before loading the module.
const LIB = path.join(HERE, 'node_modules/luau-web/src/lib/Luau.Web.Asyncify.js');
{
  let js = fs.readFileSync(LIB, 'utf8');
  const m = js.match(/findWasmBinary\(\)\{return base64Decode\("([A-Za-z0-9+/=]+)"\)/);
  let bin = Buffer.from(m[1], 'base64');
  const leb = (b, i) => { let r = 0, sh = 0, x; do { x = b[i++]; r |= (x & 0x7f) << sh; sh += 7; } while (x & 0x80); return [r, i]; };
  const enc = (v) => { const out = []; do { let x = v & 0x7f; v >>>= 7; out.push(v ? x | 0x80 : x); } while (v); return out; };
  let i = 8;
  while (i < bin.length) {
    const id = bin[i];
    const [size, j] = leb(bin, i + 1);
    if (id === 5) {
      const [, k] = leb(bin, j);
      const [pages] = leb(bin, k + 1);
      if (pages < 4096) {
        const body = [1, 0, ...enc(4096)];
        bin = Buffer.concat([bin.subarray(0, i), Buffer.from([5, ...enc(body.length), ...body]), bin.subarray(j + size)]);
        js = js.slice(0, m.index) + `findWasmBinary(){return base64Decode("${bin.toString('base64')}")` + js.slice(m.index + m[0].length);
        fs.writeFileSync(LIB, js);
      }
      break;
    }
    i = j + size;
  }
}

const { LuauState } = await import('luau-web');

function walk(dir) {
  let out = [];
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) out = out.concat(walk(p));
    else if (p.endsWith('.lua')) out.push(path.relative(SRC, p).split(path.sep).join('/'));
  }
  return out;
}

const files = walk(SRC);
let state;
let mockRef;
state = await LuauState.createAsync({
  __compile: (src, name) => state.loadstring(src, name, true),
  __listFiles: () => files.join('\n'),
  __getMock: () => mockRef,
  __readFile: (p) => fs.readFileSync(path.join(SRC, p), 'utf8'),
});
mockRef = state.loadstring(fs.readFileSync(path.join(HERE, 'mock.luau'), 'utf8'), 'mock', true)();
state.loadstring(fs.readFileSync(path.join(HERE, 'scenario.luau'), 'utf8'), 'scenario', true)();
