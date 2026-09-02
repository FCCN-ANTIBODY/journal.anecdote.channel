#!/usr/bin/env ruby
# Pure-Ruby test for bin/build-intermediates (no Jekyll, no gems). Builds a throwaway repo
# with a real gitlink and a real un-pinned directory, so the pin-reading path is exercised
# against git itself rather than a stub.
# Run: ruby test/build-intermediates.test.rb  ->  "ALL TESTS PASSED" / rc 0
require "yaml"
require "date"
require "json"
require "tmpdir"
require "fileutils"

TOOL = File.expand_path("../bin/build-intermediates", __dir__)

$pass = 0; $fail = 0
def ok(name)
  yield ? $pass += 1 : ($fail += 1; puts "  FAIL: #{name}")
rescue StandardError => e
  $fail += 1; puts "  ERROR: #{name}: #{e.class}: #{e.message}"
end

# The words a contributor wrote. They must never turn up in an intermediate: prose living in
# the AREA's history would outlive a squash of the author's own repository, and the whole
# withdrawal promise rests on it not doing that.
PROSE = "THE-CONTRIBUTORS-ACTUAL-WORDS-WHICH-MUST-NOT-TRAVEL"
PINNED_SHA = "1234567890abcdef1234567890abcdef12345678"

def front_matter(path)
  YAML.safe_load(/\A---\r?\n(.*?)\r?\n---/m.match(File.read(path))[1], permitted_classes: [Date])
end

def build(issues:)
  dir = Dir.mktmpdir("intermediates-")
  Dir.chdir(dir) do
    system("git init -q -b main && git config user.email t@t && git config user.name t", exception: true)
    File.write("_config.yml", "title: Test Area\ncivic_node: Test Area\njournal: journal\n")

    # a cited piece, pinned as a real gitlink in the tree
    File.write(".gitmodules", <<~MODS)
      [submodule "journal/beat/pinned"]
      \tpath = journal/beat/pinned
      \turl = https://example.invalid/pinned
    MODS

    # a piece that is present on disk but NOT pinned — a citation that has gone
    FileUtils.mkdir_p("journal/beat/unpinned")
    File.write("journal/beat/unpinned/index.md", "---\ntitle: Gone\n---\n\n#{PROSE}\n")

    FileUtils.mkdir_p("issues")
    issues.each { |name, body| File.write(File.join("issues", name), body) }
    # The gitlink is staged AFTER `git add -A`: the path has no working tree, so an earlier
    # add would stage its removal and the pin would never reach the commit.
    system("git add -A", exception: true)
    system("git update-index --add --cacheinfo 160000,#{PINNED_SHA},journal/beat/pinned", exception: true)
    system("git commit -q -m fixture", exception: true)
    # the pin is what the TREE records; the working copy is what a checked-out submodule looks
    # like on disk. Both, because the tool reads one for provenance and the other for prose.
    FileUtils.mkdir_p("journal/beat/pinned")
    File.write("journal/beat/pinned/index.md", <<~PIECE)
      ---
      title: A letter that ran
      author: Author One
      date: 2026-08-02
      tags: [buses, schedules]
      layout: whatever-their-site-used
      permalink: /their/old/address/
      redirect_from:
        - /older/still/
      ---

      #{PROSE}
    PIECE

    out = `ruby #{TOOL.inspect} 2>&1`
    [dir, out, $?.exitstatus]
  end
end

ISSUE = <<~MD
  ---
  title: "Test Area — 2026-08"
  layout: issue
  cut: 2026-08-18
  pieces:
    - url: "/journal/beat/pinned/"
      title: "A letter that ran"
      author: "Author One"
    - url: "/journal/beat/unpinned/"
      title: "A letter that has gone"
      author: "Author Two"
  ---

  #{PROSE}
MD

dir, out, status = build(issues: { "2026-08.md" => ISSUE, "notes.md" => "---\ntitle: not an issue\n---\n" })
ok("exits clean") { status.zero? }

Dir.chdir(dir) do
  ok("one intermediate per issue, keyed by month") { File.exist?("_intermediates/2026-08.md") }
  ok("a file that is not a month key is not an issue") { !File.exist?("_intermediates/notes.md") }

  fm = front_matter("_intermediates/2026-08.md")
  ok("the arrangement travels: issue, cut, area") do
    fm["issue"] == "2026-08" && fm["cut"].to_s == "2026-08-18" && fm["area"] == "Test Area"
  end

  pinned, gone = fm["pieces"]
  ok("a pinned piece records the commit it is pinned at") { pinned["source"] == PINNED_SHA }
  ok("a pinned piece records where it came from") { pinned["source_repo"] == "https://example.invalid/pinned" }
  ok("headline and byline travel") { pinned["title"] == "A letter that ran" && pinned["author"] == "Author One" }

  ok("an unpinned piece is still NAMED, never dropped") { gone["title"] == "A letter that has gone" }
  ok("an unpinned piece carries no source — that is what withdrawn looks like") { !gone.key?("source") }
  ok("the inert body marks it withdrawn") { File.read("_intermediates/2026-08.md").include?("*(withdrawn)*") }

  # The arrangement files this tool AUTHORS carry no prose: an issue names its pieces, it does
  # not contain them. The pieces themselves are carried separately, below.
  authored = ["_intermediates/2026-08.md", "_intermediates/current.md"]
  ok("the arrangement names its pieces and does not contain them") do
    authored.none? { |f| File.read(f).include?(PROSE) }
  end

  # ---- the pieces, carried at the path their url already names -----------------------------
  carried = "_intermediates/journal/beat/pinned/index.md"
  ok("a pinned piece is carried at the path its url names") { File.exist?(carried) }
  if File.exist?(carried)
    text = File.read(carried)
    fm = front_matter(carried)
    ok("the piece's prose travels") { text.include?(PROSE) }
    ok("keys that DESCRIBE the piece travel with it") do
      fm["title"] == "A letter that ran" && fm["author"] == "Author One" &&
        fm["date"].to_s == "2026-08-02" && fm["tags"] == %w[buses schedules]
    end
    ok("claims on a url space are dropped — nothing here was ever moved") do
      !fm.key?("permalink") && !fm.key?("redirect_from") && !fm.key?("redirect_to")
    end
    ok("the layout is dropped — a piece must not know who is publishing it") { !fm.key?("layout") }
  end
  ok("an unpinned piece is not carried") { !File.exist?("_intermediates/journal/beat/unpinned/index.md") }

  entry = front_matter("_intermediates/current.md")
  ok("the entry point indirects to the newest issue") { entry["issue"] == "2026-08" && entry["entry_point"] }
  ok("the entry point is an indirection, not a copy of the issue") do
    !File.read("_intermediates/current.md").include?("A letter that ran")
  end

  ok("intermediates are inert — nothing has to be rendered to be safe") do
    Dir.glob("_intermediates/*.md").none? { |f| File.read(f).match?(/\{\{|\{%/) }
  end
end
FileUtils.remove_entry(dir)

# The first month: nothing cut yet. It must read as a journal awaiting its first issue,
# not as a broken page.
dir2, _out2, status2 = build(issues: {})
ok("an area with no issues still exits clean") { status2.zero? }
Dir.chdir(dir2) do
  entry = front_matter("_intermediates/current.md")
  ok("with nothing cut, the entry point says so plainly") do
    entry["issue"].nil? && File.read("_intermediates/current.md").include?("No issue has been cut yet")
  end
end
FileUtils.remove_entry(dir2)

# A piece may not smuggle template syntax into a mounting site's BUILD. Nothing about a browser
# reaches this: the tag would be evaluated by whoever mounts the piece, against their includes
# and their plugins, before anything is served.
begin
  dir3 = Dir.mktmpdir("intermediates-hostile-")
  out = nil
  Dir.chdir(dir3) do
    system("git init -q -b main && git config user.email t@t && git config user.name t", exception: true)
    File.write("_config.yml", "title: Test Area\ncivic_node: Test Area\njournal: journal\n")
    File.write(".gitmodules", "[submodule \"journal/beat/pinned\"]\n\tpath = journal/beat/pinned\n\turl = https://example.invalid/p\n")
    FileUtils.mkdir_p("issues")
    File.write("issues/2026-08.md", <<~MD)
      ---
      title: "Test Area — 2026-08"
      cut: 2026-08-18
      pieces:
        - url: "/journal/beat/pinned/"
          title: "A letter with a tag in it"
          author: "Author One"
      ---
    MD
    system("git add -A", exception: true)
    system("git update-index --add --cacheinfo 160000,#{PINNED_SHA},journal/beat/pinned", exception: true)
    system("git commit -q -m fixture", exception: true)
    FileUtils.mkdir_p("journal/beat/pinned")
    File.write("journal/beat/pinned/index.md", "---\ntitle: Tagged\n---\n\n{% include contact/someone.md %}\n")
    out = `ruby #{TOOL.inspect} 2>&1`
    $hostile_status = $?.exitstatus
    $strict_out = `ruby #{TOOL.inspect} --strict 2>&1`
    $strict_status = $?.exitstatus
  end
  # The security property: a piece carrying template syntax is never carried, in either mode.
  ok("nothing was written for it") { !File.exist?(File.join(dir3, "_intermediates", "journal", "beat", "pinned", "index.md")) }
  ok("the refusal names the piece and what it found") do
    out.include?("/journal/beat/pinned/") && out.include?("{% include")
  end
  # ...but declining a piece is not declining the ISSUE. A contributor's stray include must not
  # stop every compliant letter beside it — the same posture the missing-index.md branch already
  # takes, and the one a checkpoint build depends on. The harsher failure used to be reserved for
  # the MORE recoverable problem, which was the bug.
  ok("the run still succeeds — a declined piece does not take the issue down") { $hostile_status == 0 }
  ok("the issue was still written") { File.exist?(File.join(dir3, "_intermediates", "current.md")) }
  ok("the decline is reported, not swallowed") { out.include?("NOT carried") }
  # A caller that would rather stop than publish an issue with a hole in it says so.
  ok("--strict makes a decline fatal") { $strict_status != 0 }
  ok("--strict says why it stopped") { $strict_out.include?("--strict") }
  FileUtils.remove_entry(dir3)
end

puts "\n#{$pass} passed, #{$fail} failed"
if $fail.zero?
  puts "ALL TESTS PASSED"
else
  exit 1
end
