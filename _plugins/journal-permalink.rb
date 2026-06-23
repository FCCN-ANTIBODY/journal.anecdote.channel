# Remap journal pieces from their on-disk mount dir to the public URL base.
#
# Content lives on disk under `publish/` (config: `publish`) but is served under
# `/journal/` (config: `journal`). With `permalink: pretty`, Jekyll would emit
# `/publish/autumn-ryan/foo/`; this hook swaps the leading mount segment for the
# URL base so pages land at `/journal/autumn-ryan/foo/`.
#
# We stay on vanilla pages (no collection), so `site.pages` queries in index.md
# and the sitemaps keep working unchanged. There is no permalink placeholder that
# strips the first path segment, hence this hook rather than pure config.
#
# Runs at :site, :post_read (before jekyll-redirect-from reads page urls) so that
# generated redirect stubs also point at the remapped /journal/ urls.

Jekyll::Hooks.register :site, :post_read do |site|
  mount = site.config["publish"].to_s
  base  = site.config["journal"].to_s
  next if mount.empty? || base.empty? || mount == base

  prefix = %r{\A/#{Regexp.escape(mount)}/}

  site.pages.each do |page|
    # `page.path` is the source-relative on-disk path, e.g. publish/autumn-ryan/foo/index.md
    next unless page.path.start_with?("#{mount}/")
    next if page.data.key?("permalink") # respect an explicit author/front-matter permalink

    remapped = page.url.sub(prefix, "/#{base}/")
    next if remapped == page.url

    page.data["permalink"] = remapped
    # page.url is memoized; invalidate so it recomputes from the new permalink.
    page.instance_variable_set(:@url, nil)
  end
end
