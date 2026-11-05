# UI Acceptance Baselines V1

Original fixture design and synthetic UIA tree are in ui/mockup.svg and ui/tree.json. Offscreen native Windows System.Drawing raster fixtures cover explicitly selected Light/96/en-US, Dark/144/en-US and Light/96/de-DE contexts. ui/provenance.json records original source, parameters and actual SHA256 identities. These images are generated fixtures, not desktop screenshots or observations of an application. No OS DPI/theme/locale setting is modified.

Expected comparisons: byte-identical baseline Pass; removed Save node Fail; missing live UIA/capture evidence Unknown. Choose a matching context before comparison. The original keyboard workflow focuses Display Name, types Example, tabs to Save and presses Enter; do not run global input against an arbitrary application. Real application UIA, focus, screen-reader and desktop capture acceptance are unperformed. This fixture does not claim accessibility certification.
