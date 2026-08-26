# Scope the documentation update

Part of [the Library refresh map](../map.md)
Type: grilling
Status: open

## Question

"Update the documentation" — to what scope? Grill toward a decided boundary:

- **Audience & surface**: is the target the fork's own users, or is this fork
  publishing as its own library? Does the README keep or drop the upstream
  "2026 Unified Core" banner block?
- **GettingStarted.md** is a one-line stub — write it, or delete it and fold into
  the README?
- **API.md** documents only a fraction of the 226 effect methods, is
  hand-maintained, and has been caught documenting methods that never existed —
  expand it by hand, generate it (from what yardstick — the manifest? the coverage
  ledger?), or replace it with DocC?
- **Which claims get guarded**: `ReadmeClaimsTests` pins the numbers today; do new
  or rewritten docs get the same drift protection?

The answer is a documentation spec: the list of documents, what each becomes, and
what stays untouched.
