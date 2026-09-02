# frozen_string_literal: true
#
# The media.map/v1 vocabulary — shared by bin/media-chunk (which writes maps) and
# _plugins/anecdote.rb (which renders exhibits that carry them). One home, because a
# disagreement between the writer and the renderer about which chunks a quote covers is
# a disclosure bug, not a display bug.
#
# The range spec ("0,30-36,41") is deliberately the SAME shape data-pile speaks in
# dp_ranges / dp_expand_seqs, so a disclosed set can be carried from the exhibit to
# `bin/prove --seqs` and back without translation. Keep the three in agreement by hand;
# test/media-map.test.rb pins the round-trip.
module MediaMap
  module_function

  # "0,30-36,41" -> [0,30,31,32,33,34,35,36,41]. Ascending, de-duplicated.
  # Refuses malformed input rather than returning a guess: a disclosure spec is the one
  # place a typo must not quietly reveal (or withhold) the wrong chunk.
  def expand(spec)
    return [] if spec.nil?
    return spec.map { |x| Integer(x) }.uniq.sort if spec.is_a?(Array)

    out = []
    spec.to_s.split(",").each do |part|
      p = part.strip
      next if p.empty?
      case p
      when /\A\d+\z/ then out << p.to_i
      when /\A(\d+)-(\d+)\z/
        a, b = Regexp.last_match(1).to_i, Regexp.last_match(2).to_i
        raise ArgumentError, %(descending range "#{p}") if b < a
        out.concat((a..b).to_a)
      else raise ArgumentError, %("#{p}" is not N or N-M)
      end
    end
    out.uniq.sort
  end

  # [0,3,4,5] -> "0,3-5". The inverse of expand, for stating a disclosure compactly.
  def ranges(list)
    xs = list.to_a.map { |x| Integer(x) }.uniq.sort
    return "" if xs.empty?
    out = []
    s = e = xs.first
    xs.drop(1).each do |x|
      if x == e + 1 then e = x
      else out << (s == e ? s.to_s : "#{s}-#{e}"); s = e = x
      end
    end
    out << (s == e ? s.to_s : "#{s}-#{e}")
    out.join(",")
  end

  # Which chunk indexes overlap [from, to). HALF-OPEN on purpose: a quote ending exactly
  # on a boundary must not drag in the next chunk, or every quote would silently disclose
  # one chunk more than it asked for.
  def covering(map, from, to)
    chunks(map).select { |c| c["start"] < to && (c["start"] + c["duration"]) > from }
               .map { |c| c["index"] }
  end

  def chunks(map)
    m = map.is_a?(Hash) ? map : {}
    m["chunks"].is_a?(Array) ? m["chunks"] : []
  end

  def total(map)
    chunks(map).size
  end

  # What a reader is being given, as a fraction of what exists. The denominator is the
  # attestation: a sealed exhibit still says how much recording it is standing behind.
  def disclosed_indexes(ref)
    expand(ref.is_a?(Hash) ? ref["disclosed"] : nil)
  rescue ArgumentError
    []
  end

  def state(ref)
    map = ref.is_a?(Hash) ? ref["media"] : nil
    n = total(map)
    return "sealed" if n.zero?
    d = (disclosed_indexes(ref) & (0...n).to_a).size
    return "sealed"   if d.zero?
    return "revealed" if d == n
    "partial"
  end

  # Seconds of the recording actually playable, for the caption.
  def disclosed_seconds(ref)
    map = ref.is_a?(Hash) ? ref["media"] : nil
    want = disclosed_indexes(ref)
    chunks(map).select { |c| want.include?(c["index"]) }.sum { |c| c["duration"].to_f }
  end

  def hhmmss(seconds)
    s = seconds.to_f.round
    format("%d:%02d", s / 60, s % 60)
  end
end
