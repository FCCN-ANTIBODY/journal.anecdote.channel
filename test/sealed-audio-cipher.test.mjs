// The player is browser code, but its two load-bearing agreements with data-pile are pure and
// testable here: the block cipher, and the range spec. If either drifts, a reader either cannot
// open a disclosed chunk or opens the wrong one — so they are checked against REAL openssl
// output (the same command bin/lib.sh's dp_enc runs), not against a second copy of the theory.
// Run: node test/sealed-audio-cipher.test.mjs
import { createRequire } from "node:module";
import { execFileSync } from "node:child_process";
import { mkdtempSync, writeFileSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { createHash, randomBytes } from "node:crypto";

const require = createRequire(import.meta.url);
const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const player = require(join(root, "js", "sealed-audio.js"));

let pass = 0, fail = 0;
const ok = (n, c) => c ? pass++ : (fail++, console.log("  FAIL: " + n));

console.log("the range spec agrees with MediaMap / dp_expand_seqs");
ok("expands", JSON.stringify(player.expandSpec("0,30-36,41")) === JSON.stringify([0,30,31,32,33,34,35,36,41]));
ok("de-duplicates", JSON.stringify(player.expandSpec("5,5,4-6")) === JSON.stringify([4,5,6]));
ok("empty", player.expandSpec("").length === 0);
let threw = false; try { player.expandSpec("9-2"); } catch { threw = true; }
ok("refuses a descending range", threw);
threw = false; try { player.expandSpec("1,abc"); } catch { threw = true; }
ok("refuses a non-numeric spec", threw);

console.log("the block cipher agrees with openssl aes-256-ctr, as dp_enc runs it");
const dir = mkdtempSync(join(tmpdir(), "sa-"));
let ciphered = 0;
for (const size of [1, 15, 16, 17, 4096, 165991]) {
  const key = randomBytes(32).toString("hex");
  // dp_enc: iv = sha256("iv:" || Khex)[0:32 hex chars] = first 16 bytes
  const iv = createHash("sha256").update("iv:" + key).digest("hex").slice(0, 32);
  const plain = randomBytes(size);
  const p = join(dir, "p.bin"), c = join(dir, "c.bin");
  writeFileSync(p, plain);
  execFileSync("openssl", ["enc", "-aes-256-ctr", "-K", key, "-iv", iv, "-in", p, "-out", c]);

  const got = await player.decryptChunk(key, new Uint8Array(readFileSync(c)));
  ok(`round-trips ${size} bytes through real openssl`, Buffer.compare(Buffer.from(got), plain) === 0);
  ciphered++;
}
// 165991 is a real chunk size from the Precision Security cut: past one AES block, past the
// 16-byte counter's first increments, and long enough that a wrong counter length would show.
ok("covered sizes across the block boundary", ciphered === 6);

console.log("a wrong key does not silently produce plausible bytes");
{
  const key = randomBytes(32).toString("hex"), wrong = randomBytes(32).toString("hex");
  const iv = createHash("sha256").update("iv:" + key).digest("hex").slice(0, 32);
  const plain = Buffer.from("the disclosed passage");
  const p = join(dir, "p2.bin"), c = join(dir, "c2.bin");
  writeFileSync(p, plain);
  execFileSync("openssl", ["enc", "-aes-256-ctr", "-K", key, "-iv", iv, "-in", p, "-out", c]);
  const got = await player.decryptChunk(wrong, new Uint8Array(readFileSync(c)));
  // AES-CTR is unauthenticated: the wrong key yields garbage, NOT an error. This is exactly
  // why the player checks this_hash before decrypting — the cipher will never object.
  ok("wrong key yields garbage rather than an exception", Buffer.compare(Buffer.from(got), plain) !== 0);
}

rmSync(dir, { recursive: true, force: true });
console.log(`\n${pass} passed, ${fail} failed`);
if (fail) process.exit(1); else console.log("ALL TESTS PASSED");
