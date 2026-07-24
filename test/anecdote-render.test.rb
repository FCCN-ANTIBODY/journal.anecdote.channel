#!/usr/bin/env ruby
# Pure-Ruby test for the anecdote-exhibit renderer (no Jekyll, no gems).
# Run: ruby test/anecdote-render.test.rb   ->  "ALL TESTS PASSED" / rc 0
require_relative "../_plugins/anecdote"
require "json"

$pass = 0
$fail = 0

def ok(name)
  if yield
    $pass += 1
  else
    $fail += 1
    puts "  FAIL: #{name}"
  end
rescue StandardError => e
  $fail += 1
  puts "  ERROR: #{name}: #{e.class}: #{e.message}"
end

def has(html, needle) = html.include?(needle)

# --- fixtures -------------------------------------------------------------

REVEALED = {
  "schema" => "anecdote.exhibit/v1",
  "disclosure" => "",  # derive it
  "anecdote" => {
    "schema" => "anecdote/v1", "sig" => "ed25519:deadbeef",
    "to" => { "id" => "atlas:co", "kind" => "atlas", "url" => "https://co.example" },
    "label" => "library budget cut",
    "body" => [
      { "kind" => "text", "text" => "They quietly cut the branch hours <again>.", "label" => "library budget cut" },
      { "kind" => "ref", "mediaType" => "image/png", "file" => "notice.png",
        "source" => "https://city.example/agenda", "hash" => "sha256:aa11bb22cc33dd44ee55ff66aa77bb88" },
      { "kind" => "ref", "mediaType" => "text/plain",
        "source" => "overheard", "hash" => "sha256:1234567890abcdef1234",
        "bytes" => ["the vote was 4-3"].pack("m0") },
    ],
  },
  "provenance" => {
    "origin_kind" => "atlas", "atlas_url" => "https://fort-collins.colorado.anecdote.channel/piles/cd04",
    "captured_at" => "2026-07-24", "original_ts" => "2026-07-20T18:00:00Z",
  },
}

PARTIAL = {
  "schema" => "anecdote.exhibit/v1",
  "anecdote" => {
    "schema" => "anecdote/v1",
    "label" => "water main",
    "body" => [
      { "kind" => "text", "text" => "Third break this month on Elm.", "label" => "water main" },
      { "kind" => "ref", "mediaType" => "image/jpeg", "file" => "break.jpg", "source" => "my phone",
        "hash" => "sha256:beadfeed0000111122223333" },
      { "kind" => "ref", "mediaType" => "application/pdf", "source" => "https://utility.example/report.pdf",
        "hash" => "sha256:cafebabe9999888877776666" },  # receipt only — no file
    ],
  },
  "provenance" => { "origin_kind" => "atlas", "atlas_url" => "https://co.anecdote.channel/x", "captured_at" => "2026-07-24" },
}

SEALED = {
  "schema" => "anecdote.exhibit/v1",
  "anecdote" => { "schema" => "anecdote/v1", "label" => "source claims retaliation", "body" => [] },
  "provenance" => {
    "origin_kind" => "tell",
    "signer_kid" => "SHA256:0f1e2d3c4b5a69788796a5b4c3d2e1f0",
    "content_id" => "sha256:99aa88bb77cc66dd55ee44ff33221100",
    "captured_at" => "2026-07-24",  # unsigned -> no original_ts
  },
  "proof" => { "content_id" => "sha256:99aa88bb77cc66dd55ee44ff33221100" },
}

# --- revealed -------------------------------------------------------------

r = AnecdoteExhibit.render(REVEALED)
ok("revealed: state")        { has r, 'data-disclosure="revealed"' }
ok("revealed: text escaped") { has(r, "&lt;again&gt;") && !has(r, "<again>") }
ok("revealed: image is same-origin file, not data URI") do
  has(r, 'src="./exhibits/notice.png"') && !has(r, "data:image")
end
ok("revealed: inline text ref decoded") { has r, "the vote was 4-3" }
ok("revealed: atlas origin routable link") do
  has(r, "From Atlas") && has(r, "fort-collins.colorado.anecdote.channel") && has(r, "(public, routable)")
end
ok("revealed: original timestamp shown") { has r, "original 2026-07-20T18:00:00Z" }
ok("revealed: subject heading") { has r, "library budget cut" }

# --- partial --------------------------------------------------------------

p = AnecdoteExhibit.render(PARTIAL)
ok("partial: state")            { has p, 'data-disclosure="partial"' }
ok("partial: shown image file") { has p, 'src="./exhibits/break.jpg"' }
ok("partial: receipt held")     { has(p, "held — not disclosed") && has(p, "utility.example/report.pdf") }
ok("partial: receipt has no img tag for the undisclosed ref") do
  # only ONE <img>, for break.jpg; the pdf receipt must not become an image
  p.scan("<img ").length == 1
end

# --- sealed ---------------------------------------------------------------

s = AnecdoteExhibit.render(SEALED)
ok("sealed: state")             { has s, 'data-disclosure="sealed"' }
ok("sealed: contents undisclosed") { has s, "Contents undisclosed" }
ok("sealed: provable w/ content id") { has s, "99aa88bb77cc66dd" }
ok("sealed: not routable")      { has s, "(not routable)" }
ok("sealed: signer kid shown")  { has s, "0f1e2d3c4b5a6978" }
ok("sealed: unsigned original-time note") { has s, "original time unknown (unsigned)" }
ok("sealed: no body content leaked") { !has(s, "retaliation".dup << "!") } # label ok, but no fabricated content

# --- disclosure derivation (unit) -----------------------------------------

ok("derive: empty -> sealed")   { AnecdoteExhibit.derive_disclosure([]) == "sealed" }
ok("derive: text+file -> revealed") do
  AnecdoteExhibit.derive_disclosure([
    { "kind" => "text", "text" => "hi" }, { "kind" => "ref", "file" => "a.png", "mediaType" => "image/png" },
  ]) == "revealed"
end
ok("derive: text + receipt-only ref -> partial") do
  AnecdoteExhibit.derive_disclosure([
    { "kind" => "text", "text" => "hi" }, { "kind" => "ref", "hash" => "sha256:xx", "mediaType" => "image/png" },
  ]) == "partial"
end
ok("derive: withheld text + all files -> partial") do
  AnecdoteExhibit.derive_disclosure([
    { "kind" => "text", "text" => "" }, { "kind" => "ref", "file" => "a.png", "mediaType" => "image/png" },
  ]) == "partial"
end

# --- explicit override + bare envelope + JSON path ------------------------

ok("explicit disclosure honored") do
  AnecdoteExhibit.render(SEALED.merge("disclosure" => "partial")).include?('data-disclosure="partial"')
end
ok("bare anecdote/v1 envelope renders") do
  AnecdoteExhibit.render({ "schema" => "anecdote/v1", "label" => "x",
    "body" => [{ "kind" => "text", "text" => "plain" }] }).include?("plain")
end
ok("round-trips real JSON") do
  AnecdoteExhibit.render(JSON.parse(JSON.generate(REVEALED))).include?("revealed")
end
ok("no data: image URIs anywhere (CSP img-src 'self')") do
  [r, p, s].none? { |html| html.include?("data:image") }
end

# --- report ---------------------------------------------------------------

puts "#{$pass} passed, #{$fail} failed"
if $fail.zero?
  puts "ALL TESTS PASSED"
  exit 0
else
  exit 1
end
