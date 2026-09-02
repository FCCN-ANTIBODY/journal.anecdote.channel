#!/usr/bin/env ruby
# Sealed media exhibits: a ref carrying a media.map/v1 whose bytes live in a data-pile.
# Covers the shared range vocabulary (which must agree with data-pile's dp_ranges) and the
# renderer's three disclosure states. No Jekyll, no gems, no ffmpeg, no browser.
# Run: ruby test/sealed-audio.test.rb  ->  "ALL TESTS PASSED" / rc 0
require_relative "../_plugins/media_map"
require_relative "../_plugins/anecdote"
require "json"

$pass = 0; $fail = 0
def ok(name)
  yield ? $pass += 1 : ($fail += 1; puts "  FAIL: #{name}")
rescue StandardError => e
  $fail += 1; puts "  ERROR: #{name}: #{e.class}: #{e.message}"
end
def raises(name)
  yield
  $fail += 1; puts "  FAIL: #{name} (expected a refusal)"
rescue ArgumentError
  $pass += 1
end

def map_of(n, secs = 5.0)
  { "schema" => "media.map/v1",
    "init" => { "file" => "init.mp4", "bytes" => 766 },
    "chunks" => (0...n).map { |i| { "index" => i, "file" => "c#{i}.m4s", "bytes" => 100,
                                    "start" => i * secs, "duration" => secs } },
    "duration" => n * secs }
end
def ref(n, disclosed, pile = nil)
  { "kind" => "ref", "mediaType" => "audio/mp4", "source" => "Call Recording.m4a",
    "hash" => "sha256:d5767d70", "media" => map_of(n), "disclosed" => disclosed,
    "pile" => pile || { "chunks" => "https://pile.example/inbox", "manifest" => "https://pile.example/inbox/manifest.json",
                        "keys" => "./exhibits/call.keys.json", "base_seq" => 12 } }
end
def render(r) = AnecdoteExhibit.render({ "body" => [r] })

puts "the range vocabulary (must agree with data-pile dp_ranges/dp_expand_seqs)"
ok("expands")        { MediaMap.expand("0,30-36,41") == [0, 30, 31, 32, 33, 34, 35, 36, 41] }
ok("de-duplicates")  { MediaMap.expand("5,5,4-6") == [4, 5, 6] }
ok("ranges")         { MediaMap.ranges([0, 3, 4, 5]) == "0,3-5" }
ok("round-trips")    { MediaMap.ranges(MediaMap.expand("0,30-36,41")) == "0,30-36,41" }
ok("accepts arrays") { MediaMap.expand([5, 1, 1]) == [1, 5] }
ok("empty is empty") { MediaMap.expand(nil).empty? && MediaMap.ranges([]) == "" }
raises("descending") { MediaMap.expand("9-2") }
raises("non-numeric"){ MediaMap.expand("1,abc") }

puts "covering is half-open"
m = map_of(3)
ok("inside one chunk")   { MediaMap.covering(m, 1.0, 2.0) == [0] }
ok("spanning a boundary"){ MediaMap.covering(m, 4.5, 5.5) == [0, 1] }
ok("boundary-exact does not over-disclose") { MediaMap.covering(m, 0.0, 5.0) == [0] }

puts "the three states, which are your three pieces"
ok("nothing disclosed is sealed")        { MediaMap.state(ref(10, "")) == "sealed" }
ok("some disclosed is partial")          { MediaMap.state(ref(10, "3-5")) == "partial" }
ok("all disclosed is revealed")          { MediaMap.state(ref(10, "0-9")) == "revealed" }
ok("a bad spec degrades to sealed, never to disclosed") { MediaMap.state(ref(10, "oops")) == "sealed" }
# Disclosing indexes past the end must not round up to "revealed" — that would let a typo
# claim a complete recording had been published when it had not.
ok("out-of-range indexes do not inflate the state") { MediaMap.state(ref(10, "0-8,99")) == "partial" }

puts "the exhibit's own disclosure pill"
ok("a partial recording caps the whole exhibit at partial") do
  AnecdoteExhibit.derive_disclosure([ref(10, "3-5")]) == "partial"
end
ok("a complete recording reads as revealed") do
  AnecdoteExhibit.derive_disclosure([ref(10, "0-9")]) == "revealed"
end
ok("a sealed recording reads as sealed") do
  AnecdoteExhibit.derive_disclosure([ref(10, "")]) == "sealed"
end
ok("a partial recording caps it even beside fully-shown text") do
  AnecdoteExhibit.derive_disclosure([{ "kind" => "text", "text" => "hi" }, ref(10, "3-5")]) == "partial"
end

puts "the rendered mount is inert and states the attestation"
html = render(ref(10, "3-5"))
ok("marks the disclosure state")   { html.include?('data-disclosure="partial"') }
ok("carries the disclosed set")    { html.include?('data-disclosed="3-5"') }
ok("embeds the map as JSON")       { html.include?("sealed-audio-map") && html.include?('"schema":"media.map/v1"') }
ok("states how much was disclosed"){ html.include?("0:15 of 0:50 disclosed") && html.include?("3 of 10 chunk(s)") }
ok("keeps the source hash")        { html.include?("sha256:d5767d70") }
ok("points at the pile's static files") do
  html.include?('data-manifest="https://pile.example/inbox/manifest.json"') &&
    html.include?('data-keys="./exhibits/call.keys.json"') && html.include?('data-base-seq="12"')
end
# chunk index -> pile block seq is an OFFSET, so a payload keeps its own numbering wherever
# it lands in a pile and survives the pile being appended to or rotated.
ok("carries the base seq offset")  { html.include?('data-base-seq="12"') }
ok("degrades without scripting")   { html.include?("<noscript>") }
ok("contains no player logic")     { !html.include?("<script>") && !html.match?(/on\w+=/) }

sealed = render(ref(624, ""))
ok("a sealed recording still attests to its size") { sealed.include?("624 chunk(s)") && sealed.include?("52:00") }
ok("a sealed recording discloses no chunks")       { sealed.include?('data-disclosed=""') }

full = render(ref(116, "0-115"))
ok("a complete recording says so") { full.include?("complete") && full.include?('data-disclosure="revealed"') }

# The map is embedded in a <script> block; a chunk filename containing "</script>" (or any
# "<") must not be able to close it and inject markup.
evil = ref(2, "0-1")
evil["media"]["chunks"][0]["file"] = "</script><img src=x onerror=alert(1)>.m4s"
ok("an embedded map cannot break out of its script block") do
  h = render(evil)
  !h.include?("</script><img") && h.include?("\\u003c")
end

puts "\n#{$pass} passed, #{$fail} failed"
if $fail.zero? then puts "ALL TESTS PASSED" else exit 1 end
