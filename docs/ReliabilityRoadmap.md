# Reliability Roadmap

MyCuKey's next leverage is reliability, not feature expansion. This document tracks the highest-impact places where the keyboard can still feel inconsistent, surprising, or host-dependent, and separates controllable issues from platform walls.

## Top Reliability Risks

### 1. Correction trust can still break on edge cases
- **What the user experiences:** good corrections most of the time, but occasional wrong replacements, odd revert flows, or over-learning risk can still damage trust quickly
- **How often it likely happens:** moderate, but high impact when it does
- **Control level:** under our control
- **Good enough:** obvious typos correct cleanly, learned words suppress future fights, and revert never creates a second surprise
- **Decision:** fix now

### 2. Fallback behavior is as important as feature behavior
- **What the user experiences:** when the platform blocks the ideal path, the keyboard can still feel premium if it fails gently instead of pretending it can do more than it can
- **How often it likely happens:** constant pressure across cursor logic, host rendering, and proxy-based text operations
- **Control level:** under our control
- **Good enough:** unsupported or weak paths fall back to simpler, safer behavior without creating new surprises
- **Decision:** fix now

### 3. Interaction consistency still matters more than feature count
- **What the user experiences:** key actions can feel “mostly good” overall while still having a few timing, repeat, or state-transition inconsistencies that make the keyboard feel less premium
- **How often it likely happens:** common during fast everyday typing
- **Control level:** under our control
- **Good enough:** shift, delete, popup, repeat, punctuation, and correction/revert flows behave the same way every time
- **Decision:** monitor / gather examples

### 4. Suggestion bar usefulness now needs steady expansion
- **What the user experiences:** the new suggestion bar is visibly helpful, but it can still feel too sparse, stale, or wrapper-sensitive if current-word targeting drifts
- **How often it likely happens:** common during everyday typing because the bar is now a primary repair surface
- **Control level:** under our control
- **Good enough:** the bar stays current, survives the right post-space cases, and surfaces helpful visible alternatives more often than silent autocorrection would allow
- **Decision:** fix now

### 5. Personal dictionary safety needs to stay conservative
- **What the user experiences:** the keyboard feels smarter when it remembers custom words, but it feels worse instantly if it learns the wrong thing or becomes too eager
- **How often it likely happens:** low-to-moderate, but high trust impact
- **Control level:** under our control
- **Good enough:** learned-word behavior feels safe, predictable, and easy to undo
- **Decision:** fix now

## Known Platform Limits

These are important truths, but they should not drive roadmap priority ahead of controllable reliability work.

### Keyboard host presentation artifacts
- **What the user experiences:** brief jump or flash when the keyboard appears or switches, even when the keyboard's own layout is stable
- **Control level:** mostly platform-limited
- **Good enough:** avoid adding extra motion or layout instability from MyCuKey; accept a small remaining host-level artifact if the keyboard content itself is steady

### Background coverage
- **What the user experiences:** a background image or treatment can cover the keyboard content area, but not the full system-managed region around the custom keyboard
- **Control level:** mostly platform-limited
- **Good enough:** visual treatments fill MyCuKey's own area cleanly without chasing full-screen coverage the extension does not own

### Advanced multiline cursor movement
- **What the user experiences:** vertical cursor movement is less dependable than horizontal movement because it depends on limited `UITextDocumentProxy` context after the insertion point
- **Control level:** partially under our control, heavily platform-limited
- **Good enough:** do not overpromise advanced cursor behavior unless it is truly dependable in real hosts

### Public document-model and autocorrection limits
- **What the user experiences:** some Apple-grade editing and correction behavior is missing because custom keyboards do not get a rich editable text model, full selection mutation APIs, or Apple's private correction stack
- **Control level:** platform-limited
- **Good enough:** focus effort on safe, reliable public-API behavior instead of imitating private keyboard capabilities that are not available

### UI automation reliability
- **What the user experiences:** true end-to-end XCTest coverage for the custom keyboard is weak because Simulator/XCTest does not consistently present the software keyboard for extension flows
- **Control level:** platform-limited
- **Good enough:** rely on unit tests and manual smoke checks for correction trust, and treat keyboard-extension UI automation as non-authoritative

### Tooling divergence outside Xcode
- **What the user experiences:** external CLI or MCP build/test flows can disagree with the active Xcode session because signing, provisioning, and simulator state do not always resolve the same way outside Xcode
- **Control level:** partially under our control, heavily environment-limited
- **Good enough:** use the open Xcode session as the practical source of truth when external tooling disagrees

## Reliability Validation Matrix

Run manual checks in these host types before prioritizing a new reliability fix:

- **Native single-line text field**
  - basic typing
  - correction and revert
  - delete acceleration
  - shift / caps lock
- **Native multiline editor**
  - newline handling
  - correction around punctuation
  - cursor movement expectations
  - long text deletion
- **Web or chat composer**
  - keyboard show/hide stability
  - correction triggers
  - revert behavior
  - spacing / viewport oddities

For each issue, write down:
- host app and field type
- exact user-visible symptom
- reproducibility
- whether the failure is controllable, partial, or platform-limited

## Next Controllable Work

Prioritize only the risks that are both user-visible and realistically fixable:

1. **Correction trust hardening**
   - tighten ambiguous correction behavior
   - keep personal dictionary learning conservative
   - expand regression coverage around revert and suppression flows
2. **Suggestion bar refinement**
   - broaden visible current-word suggestions without weakening silent auto-apply
   - keep wrapper handling and post-space targeting reliable
   - improve ranking so center is the strongest repair and right is the next useful alternative
3. **Fallback design**
   - prefer safe degradation over unstable advanced behavior
   - avoid shipping interactions that imply more power than the host APIs can support
4. **Scenario-based reliability review**
   - gather examples from native single-line, native multiline, and web/chat hosts
   - separate real bugs from platform ceilings before changing code

## Reliability Rules

- Do not treat host-level keyboard presentation artifacts as ordinary layout bugs unless the keyboard content itself is unstable.
- Do not ship advanced interactions that behave like a promise in UI but a fallback in reality.
- Prefer a simpler reliable behavior over a richer inconsistent behavior.
- When a limitation is platform-driven, document it internally and move roadmap energy to controllable areas.
- Do not grow autocorrection by endlessly appending one-off typo pairs. Extract mistake patterns from real examples, keep representative regression cases per pattern, and add dictionary-style one-offs only when they are both common and very safe.
