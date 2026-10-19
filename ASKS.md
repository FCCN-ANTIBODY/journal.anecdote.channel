# ASKS — upkeep

## A1 — a mounter who owns files under the engine's directory names
- status: draft
- target: the sync step

A person mounting this needs a way to say "this path is mine" from their own side, without
editing the engine, and needs the sync to refuse or say so, not delete, when a path is theirs.
(Serves C1, C2, C7.)

## A2 — a mounter deciding whether to mount
- status: draft
- target: wherever a mounter first looks

Someone deciding whether to mount needs one statement of what they must supply and what will be
overwritten. Per the method this is teaching, not law; if the constitution lacks the fact, that
is the finding. (Serves C7.)

## A3 — a build that finds nothing to do
- status: draft
- target: the stats step

A mounter whose mount path is wrong needs the build to fail, or say loudly, rather than
report success. (Serves C3.)

## A4 — someone receiving an intermediate who does not run the engine
- status: draft
- target: wherever the intermediate's contract is stated

A person receiving an intermediate needs one statement of what rendering it requires (the
engine's includes) and what they see if those are absent, and the inert-versus-tagged claim to
agree with itself. (Serves C8, C7.)
