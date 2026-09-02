#!/usr/bin/env ruby
# Pure-Ruby test for media-chunk (no Jekyll, no gems). The planner half needs nothing at
# all; the ffmpeg half is SKIPPED, stated, where ffmpeg is absent — the constellation's
# usual degradation, so this suite is useful on a box that cannot cut audio.
# Run: ruby test/media-chunk.test.rb  ->  "ALL TESTS PASSED" / rc 0
load File.expand_path("../bin/media-chunk", __dir__)
require "json"
require "tmpdir"
require "fileutils"

$pass = 0; $fail = 0
def ok(name)
  yield ? $pass += 1 : ($fail += 1; puts "  FAIL: #{name}")
rescue StandardError => e
  $fail += 1; puts "  ERROR: #{name}: #{e.class}: #{e.message}"
end
def raises(name)
  yield
  $fail += 1; puts "  FAIL: #{name} (expected a refusal, got none)"
rescue ArgumentError
  $pass += 1
end

SEGS = [{ "file" => "a.m4s", "bytes" => 100, "duration" => 5.0 },
        { "file" => "b.m4s", "bytes" => 120, "duration" => 5.0 },
        { "file" => "c.m4s", "bytes" =>  80, "duration" => 3.25 }]
INIT = { "file" => "init.mp4", "bytes" => 766 }
SRC  = { "name" => "x.m4a", "bytes" => 300, "sha256" => "sha256:ab" }

map = MediaChunk.plan(segments: SEGS, init: INIT, source: SRC, target: 5)

puts "the planner"
ok("stamps the schema")            { map["schema"] == "media.map/v1" }
ok("keeps chunks in order")        { map["chunks"].map { |c| c["index"] } == [0, 1, 2] }
ok("accumulates start times")      { map["chunks"].map { |c| c["start"] } == [0.0, 5.0, 10.0] }
ok("totals the duration")          { map["duration"] == 13.25 }
ok("carries the init segment")     { map["init"]["file"] == "init.mp4" }
ok("carries the source identity")  { map["source"]["sha256"] == "sha256:ab" }
ok("does no I/O")                  { !Dir.exist?("a.m4s") }
# The map travels with the exhibit. It must not assert losslessness nobody checked: an
# unverified cut is publishable, but only if it says so.
ok("does not claim losslessness by default") { map["chunking"]["lossless"] == "unverified" }
ok("records a verified cut as verified") do
  MediaChunk.plan(segments: SEGS, init: INIT, source: SRC, lossless: true)["chunking"]["lossless"] == true
end

puts "the planner refuses what it cannot stand behind"
raises("no segments")        { MediaChunk.plan(segments: [], init: INIT, source: SRC) }
raises("no init segment")    { MediaChunk.plan(segments: SEGS, init: nil, source: SRC) }
raises("zero duration")      { MediaChunk.plan(segments: [{ "file" => "a", "bytes" => 1, "duration" => 0 }], init: INIT, source: SRC) }
raises("empty chunk")        { MediaChunk.plan(segments: [{ "file" => "a", "bytes" => 0, "duration" => 1 }], init: INIT, source: SRC) }

puts "covering a time range"
ok("a range inside one chunk")     { MediaChunk.covering(map, 1.0, 2.0) == [0] }
ok("a range spanning a boundary")  { MediaChunk.covering(map, 4.5, 5.5) == [0, 1] }
ok("a quote starting mid-chunk takes that chunk whole") { MediaChunk.covering(map, 5.1, 9.9) == [1] }
ok("the whole recording")          { MediaChunk.covering(map, 0, 13.25) == [0, 1, 2] }
ok("past the end selects nothing") { MediaChunk.covering(map, 99, 100).empty? }
# Half-open: a range ending exactly on a boundary must not drag in the next chunk, or every
# quote would silently disclose one chunk more than it asked for.
ok("a boundary-exact range does not over-disclose") { MediaChunk.covering(map, 0.0, 5.0) == [0] }

if MediaChunk.which("ffmpeg") && MediaChunk.which("ffprobe")
  puts "the ffmpeg seam (real audio, generated here)"
  Dir.mktmpdir do |dir|
    src = File.join(dir, "tone.m4a")
    system("ffmpeg", "-v", "error", "-f", "lavfi", "-i", "sine=frequency=440:duration=12",
           "-c:a", "aac", "-b:a", "64k", src, exception: false)
    if File.file?(src)
      out = File.join(dir, "cut")
      segs = MediaChunk.segment_with_ffmpeg(src, out, 3)
      ok("cuts into several chunks")      { segs.size >= 3 }
      ok("writes an init segment")        { File.file?(File.join(out, "init.mp4")) }
      ok("every chunk file exists")       { segs.all? { |s| File.file?(File.join(out, s["file"])) } }
      ok("durations come from the playlist") { segs.all? { |s| s["duration"].to_f > 0 } }

      # The load-bearing claim: re-containering is lossless. If this ever fails, an excerpt
      # is an edit and the whole exhibit premise is void — so it is asserted, not assumed.
      want = MediaChunk.packet_md5(src)
      got  = MediaChunk.packet_md5(File.join(out, "index.m3u8"), ["-allowed_extensions", "ALL"])
      ok("reassembled chunks are byte-identical to the source") { !want.nil? && want == got }

      # A chunk alone is unreadable without init — which is WHY init ships with every excerpt.
      lone = File.join(dir, "lone.m4s")
      FileUtils.cp(File.join(out, segs[1]["file"]), lone)
      ok("a chunk without init does not parse") { !system("ffmpeg -v quiet -i #{lone} -f null - 2>/dev/null") }

      m = MediaChunk.plan(segments: segs, init: { "file" => "init.mp4", "bytes" => File.size(File.join(out, "init.mp4")) },
                          source: { "name" => "tone.m4a" }, target: 3)
      ok("planned duration tracks the source") { (m["duration"] - 12.0).abs < 0.5 }
    else
      puts "  SKIP: ffmpeg could not synthesise a fixture"
    end
  end
else
  puts "  SKIP: ffmpeg/ffprobe absent — the seam is untested here, the planner is not"
end

puts "\n#{$pass} passed, #{$fail} failed"
if $fail.zero? then puts "ALL TESTS PASSED" else exit 1 end
