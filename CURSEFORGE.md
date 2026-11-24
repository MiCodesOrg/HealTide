# HealTide

**A compact heal prediction HUD for World of Warcraft: Forever - one thin bar per card.**

HealTide shows the heals you give and receive as compact bars, even when the client hides the numbers.

Each card is a single bar:

- **Health** fills the bar from left to right, colored green → yellow → red.
- **Heals** extend the bar from the current health position to the predicted total. Your own heal is a brighter shade; other players' heals are slightly darker.
- **Overheal** turns the heal extension orange when the client signals overheal. The extension continues past the bar; its length beyond the bar is the wasted amount. Amounts are hidden and the exact severity gradient is unavailable when the client marks values secret.

The outgoing target cards and the incoming card are independent; in a group both can be visible, while the incoming card stays hidden in solo.

The bar deliberately follows the default cast bar: one row, dark background, thin border, and text inside the bar.

Your own heals on yourself appear on the outgoing **You** card; the incoming card shows heals from other players.

## Features

- Compact one-bar cards, one for the current healing target (plus group members during your heal casts) and one for incoming heals on you.
- Thin 220 × 16 default with a 1px black border, small text, and cast-bar sparks at the health and heal edges.
- Native Forever heal prediction (`UnitGetDetailedHealPrediction` / `UnitHealPredictionCalculator`). No LibHealComm, no combat log, no external libraries.
- Secret-value safe: health/heal values are handed to StatusBars; amounts are hidden, and overheal is indicated by an orange extension/cap.
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
- `/ht secrets` — secret-value diagnostics (health, calculator, incoming values).

## Compatibility

- World of Warcraft: Forever 1.60.x, interface `16001`.
- Not compatible with Retail or Classic clients without a separate port.
- No dependencies.

## Known limitations

- **Direct heals only.** Forever's native prediction does not include HoTs; HealTide does not guess them. Other players' HoTs are not exposed in combat.
- The client marks health and prediction values as secret, even outside combat. The bars still render; amounts are hidden and overheal is shown by the orange extension/cap.
- AoE heals show extra group cards during your heal casts; otherwise the current cast target is shown.
- This is a floating HUD, not a full raid-frame replacement.

## License

MIT — see `LICENSE`.
