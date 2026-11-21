# Userstyles

Original lifecycle guide. A style manager applies scoped CSS to selected pages. Static inspection cannot prove compatibility with a changing website.

## Intake and format

Choose plain CSS or manager-specific UserCSS, and record tested manager/browser versions. Specify exact page scope, target elements, desired readability changes, theme interaction, print behavior and uninstall expectations. Preserve semantic structure and host warnings. Avoid global resets and selectors that hide security, error, consent or attribution controls.

The [UserCSS example](../templates/userstyles/example.user.css) is restricted to an example.com URL prefix. It adjusts reading width and visible focus and loads no remote assets. Copy to a new project before adapting selectors. Manager metadata is not interpreted by ordinary CSS loading; scope syntax is manager/browser dependent.

## Implement the smallest override

Organize metadata, URL scope, variables, content rules, focus and media overrides. Use scoped variables and specific selectors before broad !important rules. Explain intentional overrides. Favor flexible sizing over fixed heights and overflow clipping. Do not make content unreachable to solve a visual problem.

Test narrow screens, long words, enlarged text, light/dark, print and forced colors. Respect user preferences and preserve visible keyboard focus. A color change must preserve readability in all supported contexts. Default to no motion; avoid animations that impair reading. Review selector cost if large-page behavior shows a problem rather than inventing a performance claim.

## Verify and recover

Inspect syntax and scope first, then enable through the actual manager on an inert fixture and authorized target page. Test enabled/disabled toggles, partial DOM changes, keyboard navigation, print, 200% and 400% zoom. Confirm uninstall restores the underlying page. No parsed stylesheet alone establishes these outcomes.

CSS can trigger requests through imports, fonts and URL resources. Keep offline examples self-contained and inventory every external resource if one is added. Do not embed private URLs or tokens. When a selector breaks, prefer a scoped no-op to a broad fallback that modifies unrelated content. Keep a previous version for rollback.

## Distribution and evidence

Record version, license, exact URL matches, manager/browser coverage, known conflicts and screenshots with private data removed. Review asset rights before publication. State which checks were static versus manager/site runtime. The library does not install or enable styles automatically.

Official format source checked 2026-11-21: [Stylus Writing UserCSS](https://github.com/openstyles/stylus/wiki/Writing-UserCSS). The supplied metadata and scope are a small original example. Existing [Windows design material](../../knowledge/README.md) can inform color/focus choices but does not replace testing the host page.
