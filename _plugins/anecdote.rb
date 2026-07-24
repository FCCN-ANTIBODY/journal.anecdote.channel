# Provides {% anecdote <path.json> %} — renders an anecdote/v1 envelope (or an
# anecdote.exhibit/v1 wrapper around one) that has been promoted into a piece's
# exhibits/ folder. The path is resolved relative to the current page's source
# directory, exactly like {% raw_include %}.
#
# The renderer is publish-side: it shows only what the exhibit chooses to
# divulge, across three disclosure states —
#   * sealed   — proof of possession only; contents undisclosed
#   * partial  — some parts/refs revealed, others still receipts
#   * revealed — text plus every attachment materialised
#
# Image attachments are shown from a same-origin file (the durable copy sitting
# in exhibits/), never a data: URI: the site CSP is `img-src 'self'`, and a
# pinned local file is the whole point of an exhibit. A ref that carries only a
# hash + source (no materialised file) renders as a receipt — enough to prove
# and locate, nothing disclosed.

require "json"
require "cgi"

module AnecdoteExhibit
  module_function

  def render(data, location: "./exhibits")
    schema = data.is_a?(Hash) ? data["schema"].to_s : ""
    if schema == "anecdote.exhibit/v1"
      anecdote   = hashish(data["anecdote"])
      provenance = hashish(data["provenance"])
      proof      = data["proof"]
      disclosure = data["disclosure"].to_s
    else
      anecdote   = hashish(data)
      provenance = {}
      proof      = nil
      disclosure = ""
    end

    parts      = anecdote["body"].is_a?(Array) ? anecdote["body"] : []
    signed     = !anecdote["sig"].to_s.empty?
    disclosure = derive_disclosure(parts) if disclosure.empty?

    out = +%(<article class="anecdote-exhibit" data-disclosure="#{h disclosure}">)
    out << header(anecdote, disclosure)
    out << %(\n  <div class="anecdote-body">)
    if parts.empty?
      out << sealed_body(provenance, proof)
    else
      parts.each { |p| out << "\n    " << part(hashish(p), location) }
    end
    out << %(\n  </div>)
    out << footer(provenance, signed)
    out << %(\n</article>)
    out
  end

  # ---- folder index (bibliography) ----------------------------------------

  # Render every exhibit JSON in `dir` (an absolute fs path) as one section —
  # a piece's bibliography, newest capture first — so exhibits need not be
  # hand-linked one filename at a time. `location` is the URL base the renderer
  # prepends to a materialised ref's file (default ./exhibits).
  def render_index(dir, location: "./exhibits", heading: "Exhibits")
    return "" unless File.directory?(dir)
    entries = Dir.glob(File.join(dir, "*.json")).filter_map do |path|
      data = (JSON.parse(File.read(path)) rescue nil)
      next unless exhibitish?(data)
      { id: File.basename(path, ".json"), data: data, key: index_key(data) }
    end
    return "" if entries.empty?
    # newest captured first; filename breaks ties (empties sort last in desc)
    entries.sort! { |a, b| k = b[:key] <=> a[:key]; k.zero? ? (a[:id] <=> b[:id]) : k }

    out = +%(<section class="exhibits" data-count="#{entries.size}">)
    out << %(\n  <h3 class="exhibits-heading">#{h heading}</h3>) unless heading.to_s.empty?
    entries.each do |e|
      out << %(\n  <div class="exhibit-entry" id="exhibit-#{h e[:id]}">\n)
      out << render(e[:data], location: location)
      out << %(\n  </div>)
    end
    out << %(\n</section>)
    out
  end

  def exhibitish?(data)
    data.is_a?(Hash) && data["schema"].to_s.start_with?("anecdote")
  end

  # Sort key: the exhibit's captured time; unstamped/bare envelopes sort last.
  def index_key(data)
    data["schema"].to_s == "anecdote.exhibit/v1" ? data.dig("provenance", "captured_at").to_s : ""
  end

  # ---- disclosure ---------------------------------------------------------

  def derive_disclosure(parts)
    return "sealed" if parts.empty?
    texts = parts.map { |p| hashish(p) }.select { |p| p["kind"] == "text" }
    refs  = parts.map { |p| hashish(p) }.select { |p| p["kind"] == "ref" }
    text_shown = texts.any? { |p| !p["text"].to_s.empty? }
    refs_shown = refs.select { |p| ref_shown?(p) }
    return "sealed"   if !text_shown && refs_shown.empty?
    all = (texts.empty? || text_shown) && (refs.empty? || refs_shown.size == refs.size)
    all ? "revealed" : "partial"
  end

  def ref_shown?(ref)
    return true unless ref["file"].to_s.empty?
    !ref["bytes"].to_s.empty? && textual?(ref["mediaType"])
  end

  # ---- parts --------------------------------------------------------------

  def part(p, location)
    case p["kind"]
    when "text" then text_part(p)
    when "ref"  then ref_part(p, location)
    else ""
    end
  end

  def text_part(p)
    label = p["label"].to_s
    chip  = label.empty? ? "" : %(<span class="anecdote-subject">#{h label}</span> )
    if p["text"].to_s.empty?
      %(<p class="anecdote-text withheld">#{chip}<em>text withheld</em></p>)
    else
      %(<p class="anecdote-text">#{chip}#{h p["text"]}</p>)
    end
  end

  def ref_part(ref, location)
    media = ref["mediaType"].to_s
    file  = ref["file"].to_s
    loc   = (ref["location"].to_s.empty? ? location : ref["location"].to_s).sub(%r{/\z}, "")

    unless file.empty?
      src = "#{loc}/#{file}"
      if image?(media)
        return %(<figure class="anecdote-ref">) +
               %(\n      <img src="#{h src}" alt="#{h ref["source"]}">) +
               %(\n      <figcaption>#{receipt_line(ref)}</figcaption>\n    </figure>)
      end
      return %(<p class="anecdote-ref"><a href="#{h src}">#{h file}</a> #{receipt_line(ref)}</p>)
    end

    if !ref["bytes"].to_s.empty? && textual?(media)
      text = (ref["bytes"].to_s.unpack1("m") rescue "")
      return %(<blockquote class="anecdote-ref">#{h text}<footer>#{receipt_line(ref)}</footer></blockquote>)
    end

    %(<p class="anecdote-ref receipt">#{receipt_line(ref, held: true)}</p>)
  end

  def receipt_line(ref, held: false)
    bits = []
    bits << %(<span class="mediatype">#{h ref["mediaType"]}</span>) unless ref["mediaType"].to_s.empty?
    src = ref["source"].to_s
    unless src.empty?
      bits << (src =~ %r{\Ahttps?://} ? %(<a href="#{h src}">#{h src}</a>) : %(<span class="source">#{h src}</span>))
    end
    hsh = short_hash(ref["hash"])
    bits << %(<code class="hash" title="#{h ref["hash"]}">#{h hsh}</code>) unless hsh.empty?
    bits << %(<span class="held">held — not disclosed</span>) if held
    bits.join(" ")
  end

  # ---- frame --------------------------------------------------------------

  def header(anecdote, disclosure)
    subject = anecdote["label"].to_s
    subj = subject.empty? ? "" : %(<h4 class="anecdote-subject-heading">#{h subject}</h4>)
    %(\n  <header class="anecdote-head">#{subj}\n    #{disclosure_pill(disclosure)}\n  </header>)
  end

  DISCLOSURE_LABELS = {
    "sealed"   => "held · undisclosed",
    "partial"  => "partly disclosed",
    "revealed" => "disclosed",
  }.freeze

  def disclosure_pill(d)
    %(<span class="anecdote-pill" data-disclosure="#{h d}">#{h(DISCLOSURE_LABELS[d] || d)}</span>)
  end

  def sealed_body(provenance, proof)
    cid = content_id(provenance, proof)
    tail = cid.empty? ? "" : %( for <code class="hash" title="#{h cid}">#{h short_hash(cid)}</code>)
    %(\n    <p class="anecdote-sealed"><em>Contents undisclosed.</em> Possession is provable#{tail}.</p>)
  end

  def footer(provenance, signed)
    origin = origin_badge(provenance)
    times  = timestamps(provenance, signed)
    return "" if origin.empty? && times.empty?
    %(\n  <footer class="anecdote-provenance">#{origin}#{times}</footer>)
  end

  def origin_badge(prov)
    return "" if prov.empty?
    case prov["origin_kind"].to_s
    when "atlas"
      url = prov["atlas_url"].to_s
      if url =~ %r{\Ahttps?://}
        %(<span class="origin atlas">From Atlas — <a href="#{h url}">#{h host(url)}</a> ) +
          %(<span class="routable">(public, routable)</span></span>)
      else
        %(<span class="origin atlas">From Atlas — #{h url}</span>)
      end
    else # tell / private / unspecified
      kid = prov["signer_kid"].to_s
      cid = prov["content_id"].to_s
      s = +%(<span class="origin tell">Anonymous source <span class="not-routable">(not routable)</span>)
      s << %( · signer <code class="kid" title="#{h kid}">#{h short_hash(kid)}</code>) unless kid.empty?
      s << %( · <code class="hash" title="#{h cid}">#{h short_hash(cid)}</code>) unless cid.empty?
      s << %(</span>)
      s
    end
  end

  def timestamps(prov, signed)
    cap = prov["captured_at"].to_s
    org = prov["original_ts"].to_s
    bits = []
    bits << %(<time class="captured">captured #{h cap}</time>) unless cap.empty?
    if !org.empty?
      bits << %(<time class="original">original #{h org}</time>)
    elsif !cap.empty?
      bits << %(<span class="original unknown">original time unknown#{signed ? "" : " (unsigned)"}</span>)
    end
    bits.empty? ? "" : %( <span class="times">#{bits.join(" · ")}</span>)
  end

  # ---- helpers ------------------------------------------------------------

  def content_id(prov, proof)
    return prov["content_id"].to_s unless prov["content_id"].to_s.empty?
    proof.is_a?(Hash) ? proof["content_id"].to_s : ""
  end

  def image?(media);  !!(media.to_s =~ %r{\Aimage/}); end

  def textual?(media)
    m = media.to_s
    m.start_with?("text/") || m == "application/json" || m.end_with?("+json")
  end

  def short_hash(v)
    s = v.to_s.sub(/\Asha256:/, "")
    s.length > 16 ? s[0, 16] : s
  end

  def host(url)
    require "uri"
    URI.parse(url).host || url
  rescue StandardError
    url.to_s.sub(%r{\Ahttps?://}, "").split("/").first.to_s
  end

  def hashish(v); v.is_a?(Hash) ? v : {}; end
  def h(v); CGI.escapeHTML(v.to_s); end
end

# ---- Jekyll tag (only when running inside Jekyll) -------------------------
if defined?(Liquid)
  class AnecdoteTag < Liquid::Tag
    def initialize(tag_name, markup, tokens)
      super
      @filename = markup.strip.gsub(/['"]/, "")
    end

    def render(context)
      page   = context.registers[:page]
      site   = context.registers[:site]
      dir    = File.dirname(File.join(site.source, page["path"]))
      target = File.join(dir, @filename)
      return "" unless File.exist?(target)
      AnecdoteExhibit.render(JSON.parse(File.read(target)))
    rescue JSON::ParserError => e
      %(<!-- anecdote: bad JSON in #{@filename}: #{e.message} -->)
    end
  end

  Liquid::Template.register_tag("anecdote", AnecdoteTag)

  # {% exhibits %} — render the whole exhibits/ folder as one bibliography.
  # {% exhibits some/dir %} points at a different page-relative folder.
  class ExhibitsTag < Liquid::Tag
    def initialize(tag_name, markup, tokens)
      super
      @arg = markup.strip.gsub(/['"]/, "")
    end

    def render(context)
      page = context.registers[:page]
      site = context.registers[:site]
      base = File.dirname(File.join(site.source, page["path"]))
      rel  = @arg.empty? ? "exhibits" : @arg
      AnecdoteExhibit.render_index(File.join(base, rel), location: "./#{rel}")
    end
  end

  Liquid::Template.register_tag("exhibits", ExhibitsTag)
end
