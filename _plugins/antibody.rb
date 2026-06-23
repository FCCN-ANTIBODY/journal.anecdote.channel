require "uri"

# `piece_url`: meant to be an internal url
# `any_url`: meant to be any public url

module Jekyll
  module Antibody
    def antibody_data_key(piece_url)
      # The bin/stat-*.sh writers name _data files by comma-encoding the path,
      # e.g. publish/autumn-ryan/foo/index.md -> journal,autumn-ryan,foo,index.json.
      # But Jekyll's DataReader sanitizes those filenames into hash keys by
      # DROPPING the commas (and other punctuation) while keeping word chars and
      # hyphens, so the live key is "journalautumn-ryanfooindex". We therefore
      # strip ' / and the .md suffix to land on the same crunched string — only
      # swapping the on-disk mount prefix (publish) for the URL/_data base
      # (journal) so the namespace matches what the writers prepended.

      site  = @context.registers[:site] if defined?(@context) && @context
      mount = (site && site.config["publish"]).to_s
      base  = (site && site.config["journal"]).to_s
      mount = "publish" if mount.empty?
      base  = "journal" if base.empty?

      key = piece_url.to_s.gsub("'", "").sub(/\.md\z/, "")
      key = key.sub(%r{\A/?#{Regexp.escape(mount)}/}, "#{base}/")
      key.gsub("/", "")
    end

    def antibody_domain(any_url)
      host = URI.parse(any_url.to_s).host rescue nil
      return host if host
      any_url.to_s.sub(/\Ahttps?:\/\//, "").split("/").first
    end

    def antibody_unscheme(any_url, mode = "link")
      # We softly downgrade our own links so that if/when an http downgrade
      # attack is made against a user, they are offered a chance to think very
      # carefully about what is going on invisibly in their browser.
      # i.e., //example.com reuses the existing scheme whatever that is.

      case mode
      when "label"
        any_url.to_s.sub(/\Ahttps?:/, ":")  # label-only, semi-pretty
      else
        any_url.to_s.sub(/\Ahttps?:/, "")  # actual routable // link
      end
    end
  end
end

Liquid::Template.register_filter(Jekyll::Antibody)
