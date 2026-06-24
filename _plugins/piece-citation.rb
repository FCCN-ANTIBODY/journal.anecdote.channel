# Provides {% raw_include <filename> %} for embedding piece citation guest.html
# verbatim — no Liquid processing, no Jekyll build of the guest's unknown files.
# Path is resolved relative to the current page's source directory.
class RawIncludeTag < Liquid::Tag
  def initialize(tag_name, markup, tokens)
    super
    @filename = markup.strip.gsub(/['"]/, '')
  end

  def render(context)
    page   = context.registers[:page]
    site   = context.registers[:site]
    dir    = File.dirname(File.join(site.source, page['path']))
    target = File.join(dir, @filename)
    File.exist?(target) ? File.read(target) : ''
  end
end

Liquid::Template.register_tag('raw_include', RawIncludeTag)
