# Name the gallery app's defects

Part of [the Library refresh map](../map.md)
Type: grilling
Status: open

## Question

"Debug the library app" names no symptom. What is actually wrong with the gallery
app (`Gallery/` package, launched via `make gallery`) from the user's seat — crashes,
effects rendering wrong or black, UI/UX problems, build failures, performance? On
which OS and hardware, and since when? Grill until each defect is a concrete,
reproducible statement. Cross-check against whatever
[Build and exercise the gallery app headlessly](02-gallery-headless-diagnosis.md)
turned up, so user-visible symptoms and headless findings land in one defect list.
