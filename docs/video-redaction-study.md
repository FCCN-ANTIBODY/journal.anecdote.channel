# Study: video redaction

`status: draft` — opened 2026-09-03. **A study, not a plan.** Nothing here is a commitment to build.

The journal's whole affordance is that a person puts writing, photographs and audio into their own
data-pile **in order to reveal it**, all but what they choose to hold back. Video is the medium that
affordance does not currently reach, and the reasons it does not are more interesting than "nobody
got to it yet."

## Where the engine actually stands

Worth being exact, because the gap is bigger than it looks from outside.

- **Video is not representable as an exhibit at all.** `bin/promote-exhibit`'s `EXT` map covers PNG,
  JPEG, GIF, WebP, SVG, PDF, TXT, HTML and JSON. No video type, and no audio type either.
- **Redaction today is part-level and binary.** `AnecdoteExhibit.derive_disclosure` yields
  `sealed | partial | revealed`, computed from whether each part is shown. A ref is either
  materialised as a file or it stays a receipt. There is no notion of *some of an artifact*.
- **`--seal` is the only redaction primitive**: proof-of-possession, divulge nothing but the digest.
  Total, not partial.

So "video redaction" is two capabilities stacked: video as an exhibit at all, and within-artifact
redaction as a concept. **They should be studied in that order**, and the first may be worth having
on its own.

## Why video is categorically harder than masking an image

1. **Time is a second axis, and a single miss is a full disclosure.** A face must be covered in every
   frame it appears in, while it moves. An image has one surface; a minute of video has upwards of a
   thousand, and getting 999 right is not 99.9% of the job — it is a failure.
2. **Audio is a parallel channel that leaks independently.** A spoken name identifies as well as a
   shown face. Redacting the picture and shipping the sound is a well-known and embarrassing failure
   mode, and any design that treats video as "images plus time" will walk straight into it.
3. **Blur and pixelation are not redaction.** Mosaic inversion is a solved attack, and reversibility
   scales with how much of the original signal survives. The only honest primitives are ones that
   *destroy* information — solid fill, excision, silence.
4. **Metadata survives naive processing.** Container-level metadata, location, device identifiers,
   embedded thumbnails and preview streams outlive a re-encode that only touched the video track.
5. **Size.** Video is orders of magnitude larger than anything the pile carries today. D17 already
   records an unturned knob here: a 64 KB inline cap in `composer/anecdote.mjs`, and a fountain block
   size nobody has tuned.

## The constellation-specific problem, and it is the sharp one

**Any pixel-level redaction requires re-encoding, and re-encoding produces new bytes.**

That collides with the join rule. Invariant #7 makes the content-id the join key; D10 §2 signs the
canonicalized payload and explicitly *not* the image container, precisely because encoders are not
deterministic across tools. Video is that problem raised by an order of magnitude.

The consequence is unavoidable and should be accepted rather than engineered around:

> **A redacted video is a new object, not a view of an old one.**

Which is already the constellation's answer to this shape of question elsewhere — supersession says a
replacement *keeps nothing* and is re-derived from its own content; D13 says a mask stencils one
content-addressed version and staleness is information. **Redaction is derivation, not mutation.** The
pile holds the original; the redacted artifact is its own object with its own content-id; the relation
between them is stated rather than implied.

## The split that is probably the most useful thing this study can name

There are two fundamentally different things called "a mask", and conflating them is dangerous:

| | **applied before sending** | **shipped alongside** |
| --- | --- | --- |
| what travels | only the redacted bytes | the original bytes plus a region list |
| reversible | no | **yes, trivially** |
| size | one artifact | two |
| honest use | publishing | reviewing, within a trusted boundary |

A time-coded region list is small, diffable, reviewable and pile-shaped, which makes the second column
very attractive — and it is **only safe where the original was never going to be withheld from the
recipient anyway.** Ship a mask with the bytes it hides and the mask is decorative.

The engine should probably be able to express both and must never let the second be mistaken for the
first. Naming them differently, in code and in the UI, is cheap now and expensive later.

## Not this

**Automatic detection is not a trust boundary.** A face detector that misses once has failed
catastrophically, and no accuracy figure makes that acceptable for a person who is depending on it.
Auto-detection may *propose* regions; a human disposes. Any design where the machine is the last thing
to look at the frames is out of scope, and should stay out.

**And the library is not a redaction service** (`library.anecdote.channel` `OPEN.md` §5). Redaction is
the owner's own act, in the owner's own clean room. If this work drifts into a service someone
performs on someone else's material, something has been put in the wrong place.

## What to actually study first

Small, ordered, and each answerable:

1. **Can video be an exhibit at all?** Add the types and find out what breaks. This is independent of
   redaction and may be worth doing on its own.
2. **Can a browser do the round trip with no server?** Decode, paint, re-encode, entirely on the
   device — WebCodecs is the candidate. Measure it on a phone, on a one-minute clip, and report the
   wall-clock. If it cannot be done in the clean room it cannot be done at all, because the whole
   posture is that the unredacted bytes never leave.
3. **What does the metadata sweep have to cover** for the containers people actually record in?
4. **What does the region list look like** as a pile object — small enough to diff, precise enough to
   render, and legible to someone auditing what was hidden.
5. **Audio.** Whether the same region model can carry time ranges on the audio track, or whether it
   needs its own.

Nothing above needs new cryptography (invariant #8), and nothing above should acquire any.
