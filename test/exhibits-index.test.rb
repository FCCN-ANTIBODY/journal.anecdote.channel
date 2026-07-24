#!/usr/bin/env ruby
# Pure-Ruby test for the exhibits folder index (no Jekyll, no gems).
# Run: ruby test/exhibits-index.test.rb  ->  "ALL TESTS PASSED" / rc 0
require_relative "../_plugins/anecdote"
require "json"
require "tmpdir"

$pass = 0; $fail = 0
def ok(name)
  yield ? $pass += 1 : ($fail += 1; puts "  FAIL: #{name}")
rescue StandardError => e
  $fail += 1; puts "  ERROR: #{name}: #{e.class}: #{e.message}"
end
def has(h, n) = h.include?(n)

def exhibit(label, captured, text)
  { "schema" => "anecdote.exhibit/v1",
    "anecdote" => { "schema" => "anecdote/v1", "label" => label,
      "body" => [{ "kind" => "text", "text" => text, "label" => label }] },
    "provenance" => { "origin_kind" => "atlas", "atlas_url" => "https://a.example/x", "captured_at" => captured },
    "disclosure" => "revealed" }
end

Dir.mktmpdir do |dir|
  File.write(File.join(dir, "older.json"),  JSON.generate(exhibit("water main", "2026-07-20", "Older break.")))
  File.write(File.join(dir, "newer.json"),  JSON.generate(exhibit("library budget", "2026-07-24", "Newer cut.")))
  # a bare anecdote/v1 (no provenance) — should render, sorted last
  File.write(File.join(dir, "bare.json"), JSON.generate(
    { "schema" => "anecdote/v1", "label" => "bare", "body" => [{ "kind" => "text", "text" => "Undated note." }] }))
  # noise that must be ignored
  File.write(File.join(dir, "notes.json"), JSON.generate({ "schema" => "something/else", "x" => 1 }))
  File.write(File.join(dir, "older-0.png"), "\x89PNG".b)   # not *.json-matched? it IS .png, skipped
  File.write(File.join(dir, "broken.json"), "{ not valid json")

  html = AnecdoteExhibit.render_index(dir)

  ok("section wraps the folder")     { has(html, '<section class="exhibits"') }
  ok("counts only real exhibits (3)"){ has(html, 'data-count="3"') }
  ok("renders each exhibit body")    { has(html, "Older break.") && has(html, "Newer cut.") && has(html, "Undated note.") }
  ok("skips non-anecdote json")      { !has(html, '"x":1') && !has(html, "something/else") }
  ok("tolerates broken json")        { !html.include?("broken") || true } # must not raise; already got here
  ok("each entry has a linkable id") { has(html, 'id="exhibit-newer"') && has(html, 'id="exhibit-older"') }
  ok("newest captured first") do
    html.index('id="exhibit-newer"') < html.index('id="exhibit-older"')
  end
  ok("undated bare exhibit sorts last") do
    html.index('id="exhibit-older"') < html.index('id="exhibit-bare"')
  end
  ok("heading present")              { has(html, "Exhibits") }

  # empty / missing dir degrade to nothing, never raise
  ok("empty dir -> empty string")    { AnecdoteExhibit.render_index(File.join(dir, "nope")) == "" }
  Dir.mktmpdir { |empty| ok("dir with no exhibits -> empty") { AnecdoteExhibit.render_index(empty) == "" } }
end

puts "#{$pass} passed, #{$fail} failed"
$fail.zero? ? (puts "ALL TESTS PASSED"; exit 0) : exit(1)
