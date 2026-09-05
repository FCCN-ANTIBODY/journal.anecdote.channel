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

## The actual strategy: reveal byte ranges from the pile

**Redaction is not painting. It is not revealing.**

The root journal has a data-pile, and a pile can already **prove ranges of bytes**. Layer 3 of
`data-pile/CONTRACT.md` is a forward hash ratchet: every block is committed in a signed manifest,
`bin/prove` publishes a checkpoint key, and anyone can decrypt from there and confirm each plaintext
against what was already committed. A withheld segment is not blacked out — **its bytes are simply
not disclosed**, and the manifest still proves that something was there and what its digest was.

That is the mechanism. Everything below is about the places it does not reach on its own.

### The constraint nobody has hit yet: the ratchet reveals a SUFFIX, not a range

`K_{seq+1} = sha256("ratchet:" || K_seq)`, so publishing `K_n` lets anyone derive every key after it.
The contract says so plainly: *"publishing a later checkpoint proves only from that point forward."*

**Forward-only disclosure gives you a suffix.** It cannot express *reveal 1–4 and 8–10, withhold
5–7* — and withholding a middle is precisely the video case, because the thing you are hiding
appears partway through a clip and then stops.

Two ways out, and the second needs nothing new:

1. Independently-derived per-block keys instead of a chain. This changes Layer 1 and edges toward new
   key machinery, which invariant #8 says to avoid.
2. **Split across feeds.** A pile already carries several `feed/<source>` branches and processes each
   independently. Put the withheld segments on a feed that is never disclosed and the revealed ones
   on a feed that is — arbitrary ranges, expressed entirely with machinery that exists.

Either way this is **`data-pile`'s contract question, not the journal's**, and it should be raised
there rather than worked around here.

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

## Where omission stops working, and the principle that resolves it

**The codec has too much to say.** Bytes missing from the middle of an encoded stream do not yield a
stream that plays with a gap in it; they yield a broken file. Deliberately damaging the stream is not
a redaction technique, it is a corruption technique, and what appears on screen afterwards is the
decoder's opinion rather than anyone's intent. So for the frames where a region must go, **some
frames have to be re-encoded.** There is no version of this where that is avoided.

### Embrace it: if we are modifying the frame, modify it all the way

The instinct to fight this — to make the redacted frames blend in, match grain, preserve the encode
so seamlessly that nobody can tell — is the wrong instinct, and inverting it turns the problem into
the feature.

> **A reconstructed frame should announce itself.** Do not imply that what was modified slips
> seamlessly in, because there really is a difference, and hiding the difference is a lie about the
> artifact's own provenance.

Why this is better rather than merely honest:

- **It moves the trust question off the pixels.** "Did they blur it well enough?" stops mattering when
  the frame is not pretending to be original footage. The viewer is not being asked to assess a
  cover-up; they are being shown a composite that says so.
- **It makes the seam visible in the artifact itself.** A viewer can see which frames are proven
  original bytes and which are reconstruction. That distinction is the whole point and it should not
  live only in metadata that travels separately and gets lost.
- **It is consistent with the constellation's other refusals.** Edit masks do not alter their target;
  supersession does not edit in place; a distributor is legible as a distributor rather than mistaken
  for the author. Making a reconstruction obviously a reconstruction is the same rule applied to
  pixels.

**Metadata posture that follows from it:** preserve as much as can be preserved, and be explicit that
some is damaged. A re-encode destroys things, and claiming otherwise is worse than losing them. What
is preserved should be stated; what was necessarily lost should be stated too.

## The constellation-specific problem, and it is the sharp one

**Any pixel-level redaction requires re-encoding, and re-encoding produces new bytes.**

That collides with the join rule. Invariant #7 makes the content-id the join key; D10 §2 signs the
canonicalized payload and explicitly *not* the image container, precisely because encoders are not
deterministic across tools. Video is that problem raised by an order of magnitude.

The consequence is unavoidable and should be accepted rather than engineered around:

> **A redacted video is a new object, not a view of an old one.**

**Refined, given the pile:** it is a **hybrid**, and that is better than either extreme. The revealed
byte ranges are original and provable against the signed manifest; only the re-encoded frames are
new, and those declare themselves. So the artifact is not "trust me, this is the video minus a bit" —
it is *these ranges are proven to be exactly what was recorded, and these frames are reconstruction,
and here is the boundary.*

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

0. **Raise the suffix-versus-range constraint with `data-pile`.** Nothing else here is designable
   until it is known whether arbitrary ranges are expressible, and the split-across-feeds answer needs
   that repo's opinion. This is the first move.
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
