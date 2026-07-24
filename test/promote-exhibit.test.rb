#!/usr/bin/env ruby
# Pure-Ruby test for the promote-exhibit tool (no Jekyll, no gems).
# Run: ruby test/promote-exhibit.test.rb  ->  "ALL TESTS PASSED" / rc 0
load File.expand_path("../bin/promote-exhibit", __dir__)
require_relative "../_plugins/anecdote"
require "json"
require "tmpdir"
require "fileutils"

$pass = 0; $fail = 0
def ok(name)
  yield ? $pass += 1 : ($fail += 1; puts "  FAIL: #{name}")
rescue StandardError => e
  $fail += 1; puts "  ERROR: #{name}: #{e.class}: #{e.message}"
end
def has(h, n) = h.include?(n)

PNG = "\x89PNG\r\n\x1a\n".b
PNG_B64 = [PNG].pack("m0")

def anecdote(with_receipt: true, signed: false)
  refs = [{ "kind" => "ref", "mediaType" => "image/png", "source" => "https://city.example/agenda",
            "hash" => "sha256:aa11bb22", "bytes" => PNG_B64 }]
  refs << { "kind" => "ref", "mediaType" => "application/pdf", "source" => "https://x.example/r.pdf",
            "hash" => "sha256:cafebabe" } if with_receipt
  a = { "schema" => "anecdote/v1", "to" => { "id" => "atlas:co", "kind" => "atlas", "url" => "https://co.example/p" },
        "label" => "Library Budget Cut!", "body" => [{ "kind" => "text", "text" => "They cut it.", "label" => "library budget cut" }] + refs }
  a.merge!("sig" => "ed25519:deed", "agent" => "kid:abcd1234", "ts" => "2026-07-20T18:00:00Z") if signed
  a
end

# --- materialisation (partial: a receipt-only ref remains) ------------------

r = PromoteExhibit.build(anecdote, atlas_url: "https://fc.co.anecdote.channel/piles/cd04")
ok("slug from label")            { r[:slug] == "library-budget-cut" }
ok("one file materialised")      { r[:files].size == 1 && r[:files][0][:name] == "library-budget-cut-1.png" }
ok("materialised bytes are the real binary") { r[:files][0][:bytes] == PNG }
ok("materialised ref points at file, no bytes") do
  ref = r[:exhibit]["anecdote"]["body"][1]
  ref["file"] == "library-budget-cut-1.png" && !ref.key?("bytes")
end
ok("receipt ref untouched")      { r[:exhibit]["anecdote"]["body"][2]["file"].nil? && r[:exhibit]["anecdote"]["body"][2]["hash"] == "sha256:cafebabe" }
ok("disclosure partial (receipt remains)") { r[:exhibit]["disclosure"] == "partial" }
ok("atlas provenance routable")  { p = r[:exhibit]["provenance"]; p["origin_kind"] == "atlas" && p["atlas_url"].include?("cd04") }
ok("captured_at stamped")        { r[:exhibit]["provenance"]["captured_at"] =~ /\A\d{4}-\d{2}-\d{2}\z/ }
ok("content_id computed")        { r[:exhibit]["provenance"]["content_id"].start_with?("sha256:") }
ok("no bytes leak into exhibit") { !JSON.generate(r[:exhibit]).include?(PNG_B64) }

# --- fully revealed (no receipt-only ref) -----------------------------------

rev = PromoteExhibit.build(anecdote(with_receipt: false))
ok("revealed when all refs materialised") { rev[:exhibit]["disclosure"] == "revealed" }

# --- signed anecdote carries original time ----------------------------------

sg = PromoteExhibit.build(anecdote(signed: true))
ok("original_ts read from signed anecdote") { sg[:exhibit]["provenance"]["original_ts"] == "2026-07-20T18:00:00Z" }

# --- seal: proof only, nothing divulged -------------------------------------

sealed = PromoteExhibit.build(anecdote, seal: true, origin: "tell", signer_kid: "SHA256:facefeed")
ok("seal drops body")            { sealed[:exhibit]["anecdote"]["body"] == [] }
ok("seal writes no files")       { sealed[:files].empty? }
ok("seal state")                 { sealed[:exhibit]["disclosure"] == "sealed" }
ok("seal carries proof")         { sealed[:exhibit]["proof"]["content_id"].start_with?("sha256:") }
ok("seal tell provenance non-routable") { sealed[:exhibit]["provenance"]["origin_kind"] == "tell" && sealed[:exhibit]["provenance"]["signer_kid"] == "SHA256:facefeed" }
ok("seal leaks no body text")    { !JSON.generate(sealed[:exhibit]).include?("They cut it") }

# --- explicit content-id honoured; determinism ------------------------------

ok("explicit content-id honoured") { PromoteExhibit.build(anecdote, content_id: "sha256:deadbeef")[:exhibit]["provenance"]["content_id"] == "sha256:deadbeef" }
ok("content_id deterministic") do
  PromoteExhibit.build(anecdote)[:exhibit]["provenance"]["content_id"] ==
    PromoteExhibit.build(anecdote)[:exhibit]["provenance"]["content_id"]
end

# --- the produced exhibit round-trips through the renderer ------------------

html = AnecdoteExhibit.render(r[:exhibit])
ok("round-trip: renders the materialised image as same-origin file") { has(html, 'src="./exhibits/library-budget-cut-1.png"') && !has(html, "data:image") }
ok("round-trip: receipt held")   { has(html, "held — not disclosed") }
ok("round-trip: partial state")  { has(html, 'data-disclosure="partial"') }

# --- CLI + filesystem end to end --------------------------------------------

Dir.mktmpdir do |dir|
  piece = File.join(dir, "piece")
  FileUtils.mkdir_p(piece)
  src = File.join(dir, "a.json")
  File.write(src, JSON.generate(anecdote))
  bin = File.expand_path("../bin/promote-exhibit", __dir__)
  out = `ruby #{bin} #{src} --into #{piece} --atlas-url https://fc.co.anecdote.channel/x 2>&1`
  jpath = File.join(piece, "exhibits", "library-budget-cut.json")
  ppath = File.join(piece, "exhibits", "library-budget-cut-1.png")
  ok("CLI: json written")   { File.exist?(jpath) }
  ok("CLI: png written")    { File.exist?(ppath) && File.binread(ppath) == PNG }
  ok("CLI: json is valid exhibit") { JSON.parse(File.read(jpath))["schema"] == "anecdote.exhibit/v1" }
  ok("CLI: prints tag hint") { has(out, "{% anecdote exhibits/library-budget-cut.json %}") }
  ok("CLI: dry-run touches nothing") do
    d2 = File.join(dir, "piece2"); FileUtils.mkdir_p(d2)
    `ruby #{bin} #{src} --into #{d2} --dry-run 2>&1`
    !File.exist?(File.join(d2, "exhibits"))
  end
end

puts "#{$pass} passed, #{$fail} failed"
$fail.zero? ? (puts "ALL TESTS PASSED"; exit 0) : exit(1)
