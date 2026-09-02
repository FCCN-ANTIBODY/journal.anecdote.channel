// Sealed audio exhibits — play the disclosed parts of a recording, paint the rest dark.
//
// The exhibit ships a media.map/v1 (every chunk, its offset, its size) and a disclosed set.
// The bytes live in a data-pile as per-chunk drop blocks, each encrypted under its own key.
// Publishing a quote publishes only those chunks' keys, so what is not disclosed is not
// merely hidden here — it is unavailable, and the map still attests that it exists.
//
// WHAT THIS VERIFIES, AND WHAT IT DOES NOT.
// Every chunk is checked against the `this_hash` the signed manifest publishes for it BEFORE
// it is decrypted, and a mismatch refuses rather than plays. That is the per-block half of
// data-pile's partial verification. The manifest-level half — digest, signature, prev_hash
// linkage — needs data-pile's feed-open.mjs, which this page cannot import (the engine loads
// plain scripts, and data-pile is not a submodule here). So this player trusts that the
// manifest it fetched is the right manifest, and proves only that the bytes match it. That
// is a real limit and it is deliberate; see E1-sealed-exhibits "Do".
//
// THE CIPHER IS MIRRORED, NOT SHARED. This is the third implementation of the block layout
// (data-pile bin/lib.sh, data-pile bin/feed-open.mjs, here). It must agree byte-for-byte:
//   iv = sha256("iv:" || Khex)[0:16],  AES-256-CTR, full 16-byte counter (length 128)
// If you change one, change all three.
//
// UNVERIFIED IN A BROWSER as of 2026-09-02. The MSE gap-jumping below is written from the
// spec: appending non-contiguous fragments yields disjoint buffered ranges, and the element
// STALLS at a hole rather than skipping it, so the playhead has to be moved deliberately.
// Confirm on the first real build before trusting the seek behaviour.

(function () {
  "use strict";

  var hex = function (buf) {
    var out = "", b = new Uint8Array(buf);
    for (var i = 0; i < b.length; i++) out += b[i].toString(16).padStart(2, "0");
    return out;
  };
  var unhex = function (s) {
    var a = new Uint8Array(s.length / 2);
    for (var i = 0; i < a.length; i++) a[i] = parseInt(s.substr(i * 2, 2), 16);
    return a;
  };
  var sha256hex = function (bytes) {
    return crypto.subtle.digest("SHA-256", bytes).then(hex);
  };

  // Mirrors dp_expand_seqs / MediaMap.expand. Refuses malformed input rather than guessing.
  function expandSpec(spec) {
    var out = [];
    (spec || "").split(",").forEach(function (part) {
      var p = part.trim();
      if (!p) return;
      var m;
      if ((m = /^(\d+)$/.exec(p))) out.push(+m[1]);
      else if ((m = /^(\d+)-(\d+)$/.exec(p))) {
        var a = +m[1], b = +m[2];
        if (b < a) throw new Error("descending range " + p);
        for (var i = a; i <= b; i++) out.push(i);
      } else throw new Error("bad range spec " + p);
    });
    return out.filter(function (v, i, xs) { return xs.indexOf(v) === i; }).sort(function (x, y) { return x - y; });
  }

  function fmt(t) {
    t = Math.max(0, Math.round(t || 0));
    return Math.floor(t / 60) + ":" + String(t % 60).padStart(2, "0");
  }

  // ---- one mount ----------------------------------------------------------
  function setup(mount) {
    var fig = mount.closest(".sealed-audio") || mount.parentNode;
    var mapEl = fig.querySelector(".sealed-audio-map");
    if (!mapEl) return;

    var map;
    try { map = JSON.parse(mapEl.textContent); } catch (e) { return fail(mount, "exhibit map is unreadable"); }
    var chunks = (map.chunks || []);
    if (!chunks.length) return;

    var disclosed;
    try { disclosed = expandSpec(mount.dataset.disclosed); } catch (e) { disclosed = []; }
    var total = +map.duration || chunks.reduce(function (a, c) { return a + c.duration; }, 0);

    var ui = build(mount, map, chunks, disclosed, total);
    if (!disclosed.length) return;                       // sealed: the timeline IS the exhibit

    if (!window.MediaSource || !window.crypto || !crypto.subtle) {
      return fail(mount, "this browser cannot play sealed audio (needs MediaSource and WebCrypto)");
    }
    // Sub-resources are fetched cross-origin from the pile and decrypted here, so a page
    // served over plain http has no crypto.subtle at all. Say so rather than half-working.
    if (!window.isSecureContext) return fail(mount, "sealed audio needs a secure context (https)");

    play(mount, ui, map, chunks, disclosed, total).catch(function (e) {
      fail(mount, (e && e.message) || "could not open the sealed audio");
    });
  }

  function fail(mount, msg) {
    var p = document.createElement("p");
    p.className = "sealed-audio-error";
    // The attestation outlives the player: if playback is impossible, the reader should still
    // be told what exists and how much of it was disclosed.
    p.textContent = msg;
    mount.appendChild(p);
  }

  // ---- the timeline -------------------------------------------------------
  function build(mount, map, chunks, disclosed, total) {
    mount.textContent = "";
    var audio = document.createElement("audio");
    audio.controls = true;
    audio.preload = "none";
    var label = (map.source && map.source.name) || "sealed recording";
    audio.setAttribute("aria-label", label + " — " + fmt(total) + ", " + disclosed.length + " of " + chunks.length + " chunks disclosed");

    var bar = document.createElement("div");
    bar.className = "sealed-audio-timeline";
    bar.setAttribute("role", "img");
    bar.setAttribute("aria-label", disclosed.length
      ? "Timeline: " + disclosed.length + " of " + chunks.length + " chunks disclosed; the rest is sealed"
      : "Timeline: nothing disclosed; the whole recording is sealed");

    // One element per chunk, width proportional to its duration. Dark chunks are not merely
    // unplayed — there is no key for them — so they are marked, not hidden.
    var lit = {};
    disclosed.forEach(function (i) { lit[i] = true; });
    chunks.forEach(function (c) {
      var seg = document.createElement("span");
      seg.className = "sealed-audio-seg " + (lit[c.index] ? "lit" : "dark");
      seg.style.flex = String(c.duration || 0);
      seg.title = fmt(c.start) + "–" + fmt(c.start + c.duration) + (lit[c.index] ? "" : " — sealed");
      bar.appendChild(seg);
    });

    var note = document.createElement("p");
    note.className = "sealed-audio-note";
    mount.appendChild(audio); mount.appendChild(bar); mount.appendChild(note);
    return { audio: audio, bar: bar, note: note, lit: lit };
  }

  // ---- fetch, verify, decrypt, append -------------------------------------
  function play(mount, ui, map, chunks, disclosed, total) {
    var d = mount.dataset;
    var base = (d.chunks || d.location || ".").replace(/\/$/, "");
    var baseSeq = +(d.baseSeq || 0);

    return Promise.all([
      d.manifest ? fetch(d.manifest, { mode: "cors" }).then(function (r) { return r.json(); }) : Promise.resolve(null),
      d.keys ? fetch(d.keys, { mode: "cors" }).then(function (r) { return r.json(); }) : Promise.resolve(null),
    ]).then(function (both) {
      var manifest = both[0], bundle = both[1];
      if (!bundle || !bundle.block_keys) throw new Error("no disclosure bundle — nothing can be opened");

      var ms = new MediaSource();
      ui.audio.src = URL.createObjectURL(ms);
      return new Promise(function (resolve, reject) {
        ms.addEventListener("sourceopen", function () {
          var sb;
          try { sb = ms.addSourceBuffer(d.codec || 'audio/mp4; codecs="mp4a.40.2"'); }
          catch (e) { return reject(new Error("this browser will not decode " + (d.codec || "audio/mp4"))); }

          // The element's duration is the WHOLE recording, not the disclosed part: the
          // timeline must show what is sealed, and a shortened duration would hide it.
          try { ms.duration = total; } catch (e) { /* set once data lands */ }

          var queue = [{ init: true, file: map.init.file, seq: null }].concat(
            disclosed.map(function (i) { return { file: chunks[i].file, seq: baseSeq + i, index: i }; })
          );

          var step = function (n) {
            if (n >= queue.length) {
              try { if (ms.readyState === "open") ms.endOfStream(); } catch (e) {}
              gapJump(ui, chunks, ui.lit);
              return resolve();
            }
            var item = queue[n];
            openChunk(base, item, manifest, bundle)
              .then(function (bytes) {
                return append(sb, bytes).then(function () { step(n + 1); });
              })
              .catch(reject);
          };
          step(0);
        }, { once: true });
      });
    });
  }

  function append(sb, bytes) {
    return new Promise(function (resolve, reject) {
      sb.addEventListener("updateend", function () { resolve(); }, { once: true });
      sb.addEventListener("error", function () { reject(new Error("the decoder rejected a chunk")); }, { once: true });
      try { sb.appendBuffer(bytes); } catch (e) { reject(e); }
    });
  }

  // Fetch one chunk, CHECK IT AGAINST THE MANIFEST BEFORE DECRYPTING, then decrypt.
  // AES-CTR is unauthenticated: a tampered chunk would decrypt to plausible garbage and
  // play, so the hash check is what stands between a reader and forged audio. It is not
  // optional and there is no flag to skip it.
  function openChunk(base, item, manifest, bundle) {
    return fetch(base + "/" + encodeURIComponent(item.file) + (item.init ? "" : ".enc"), { mode: "cors" })
      .then(function (r) {
        if (!r.ok) throw new Error("chunk " + item.file + " is not retrievable (" + r.status + ")");
        return r.arrayBuffer();
      })
      .then(function (buf) {
        var bytes = new Uint8Array(buf);
        if (item.init) return bytes;                     // the init segment ships in the clear
        var entry = manifest && manifest.entries && manifest.entries[item.seq];
        var key = bundle.block_keys[String(item.seq)];
        if (!key) throw new Error("no key for chunk at seq " + item.seq);
        var checked = entry
          ? sha256hex(bytes).then(function (got) {
              if ("sha256:" + got !== entry.this_hash) {
                throw new Error("chunk at seq " + item.seq + " does not match the manifest — refusing to play it");
              }
            })
          : Promise.reject(new Error("no manifest entry for seq " + item.seq + " — cannot verify, refusing"));
        return checked.then(function () { return decryptChunk(key, bytes); });
      });
  }

  function decryptChunk(kHex, cipher) {
    return sha256hex(new TextEncoder().encode("iv:" + kHex)).then(function (ivHex) {
      var iv = unhex(ivHex.slice(0, 32));
      return crypto.subtle.importKey("raw", unhex(kHex), { name: "AES-CTR" }, false, ["decrypt"])
        .then(function (k) {
          // length:128 = the whole 16-byte block is the counter, matching openssl aes-256-ctr.
          return crypto.subtle.decrypt({ name: "AES-CTR", counter: iv, length: 128 }, k, cipher);
        })
        .then(function (out) { return new Uint8Array(out); });
    });
  }

  // ---- the playhead over holes -------------------------------------------
  // Appending non-contiguous fragments leaves the buffered ranges disjoint, and the element
  // STALLS at a hole rather than skipping it. So the playhead is moved deliberately: on stall
  // (or on approach), jump to the start of the next buffered range and say that it happened.
  function gapJump(ui, chunks, lit) {
    var a = ui.audio;
    var nextStart = function (t) {
      for (var i = 0; i < a.buffered.length; i++) {
        if (a.buffered.start(i) > t + 0.01) return a.buffered.start(i);
      }
      return null;
    };
    var inside = function (t) {
      for (var i = 0; i < a.buffered.length; i++) {
        if (t >= a.buffered.start(i) - 0.01 && t < a.buffered.end(i)) return true;
      }
      return false;
    };
    var skip = function () {
      if (a.paused || inside(a.currentTime)) return;
      var n = nextStart(a.currentTime);
      if (n === null) { a.pause(); ui.note.textContent = "End of the disclosed audio."; return; }
      ui.note.textContent = "Skipped a sealed stretch — resuming at " + fmt(n) + ".";
      a.currentTime = n;
    };
    a.addEventListener("waiting", skip);
    a.addEventListener("timeupdate", function () {
      if (!inside(a.currentTime)) skip();
      var pct = (a.currentTime / (a.duration || 1)) * 100;
      ui.bar.style.setProperty("--playhead", pct.toFixed(2) + "%");
    });
    // Seeking into a dark stretch is a legitimate gesture with an honest answer: move to the
    // next thing that exists, rather than appearing to play silence that was never disclosed.
    a.addEventListener("seeked", function () { if (!inside(a.currentTime)) skip(); });
  }

  // The cipher and the range spec are the two things that MUST agree with data-pile
  // (bin/lib.sh and bin/feed-open.mjs). Exposed so test/sealed-audio-cipher.test.mjs can
  // check them against real openssl output under node, where there is no browser to drive.
  if (typeof module !== "undefined" && module.exports) {
    module.exports = { expandSpec: expandSpec, decryptChunk: decryptChunk, fmt: fmt };
  }

  if (typeof document !== "undefined" && document.addEventListener) {
    document.addEventListener("DOMContentLoaded", function () {
      var mounts = document.querySelectorAll(".sealed-audio-mount");
      for (var i = 0; i < mounts.length; i++) setup(mounts[i]);
    });
  }
})();
