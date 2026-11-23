# HealTide

**A compact heal prediction HUD for World of Warcraft: Forever - one thin bar per card.**

HealTide shows who is being healed, by how much, and how much would be wasted, in a compact cast-style bar per card.

Each card is a single bar:

- **Health** fills the bar from left to right, colored green → yellow → red.
- **Heals** extend the bar from the current health position to the predicted total. Your own heal is a brighter shade; other players' heals are slightly darker.
- **Overheal** colors the heal extension: green (fully effective), yellow (a little wasted), orange (a lot), red (mostly or fully wasted). The heal extension, bar border, and a small end cap use the same color. When the heal exceeds max health, the extension continues past the bar; its length beyond the bar is the wasted amount.

The outgoing target cards and the incoming card are independent, so both can be visible at the same time.

The bar deliberately follows the default cast bar: one row, dark background, thin border, and text inside the bar.

Your own heals on yourself appear on the outgoing **You** card; the incoming card independently shows heals from other players, so both can be visible at the same time.

## Features

- Compact one-bar cards for the current healing target (plus group members when the player's contribution is readable) and for incoming heals on you.
- Thin 220 × 16 default with a 1px black border, small text, and cast-bar sparks at the health and heal edges.
- Native Forever heal prediction (`UnitGetDetailedHealPrediction` / `UnitHealPredictionCalculator`). No LibHealComm, no combat log, no external libraries.
- Secret-value safe: health/heal values are handed to StatusBars; numeric text is hidden when the client marks values secret.
- Movable cards and a lock mode.
- Built-in demo mode (`/ht test`) for layout checks without a group.
- Full `/ht` command set; `/ht status` diagnostics.

## Installation

1. Unzip `HealTide` into `World of Warcraft\_forever_\Interface\AddOns\`.
2. `/reload`.
3. Enable **HealTide**.
4. `/ht status` should report `Prediction: OK | clamps: MaximumHealth / MissingHealth | two calculators: yes`.

## Commands

- `/ht test` — demo cards (target 50%: 250 from others + 350 from you, 100 overheal; you 70%: 300 incoming).
- `/ht live` — real values for 10 s.
- `/ht stop` — hide demo cards.
- `/ht unlock` / `/ht lock` — move/lock cards.
- `/ht outgoing` / `/ht incoming` — toggle card types.
- `/ht healsonly` — toggle the heal-spell filter.
- `/ht width 220`, `/ht height 16` - card size (width 120–500, height 10–40).
- `/ht spacing 2` — gap between cards (0–20).
- `/ht reset` — defaults.
- `/ht status` — API/settings/diagnostics.

## Compatibility

- World of Warcraft: Forever 1.60.x, interface `16001`.
- Not compatible with Retail or Classic clients without a separate port.
- No dependencies.

## Known limitations

- **Direct heals only.** Forever's native prediction does not include HoTs; HealTide does not guess them. Other players' HoTs are not exposed in combat.
- Secret values in combat can hide numeric text; the cards still render, and the heal extension stays proportional with a red end cap when overheal is detected.
- AoE heals show extra cards when the player's contribution is readable; otherwise the current cast target is shown.
- This is a floating HUD, not a full raid-frame replacement.

## License

MIT — see `LICENSE`.
