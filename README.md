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

- Compact one-bar cards, one for the current healing target (plus group members when the player's contribution is readable) and one for incoming heals on you.
- Thin 220 × 16 default with a 1px black border, small text, and cast-bar sparks at the health and heal edges.
- Native Forever heal prediction through `UnitGetDetailedHealPrediction` / `UnitHealPredictionCalculator`; no LibHealComm, no combat log.
- Secret-value safe: health/heal values go straight into StatusBars; amounts and severity colors use the client's secret-safe formatter when available.
- Movable cards with a lock mode.
- Built-in demo mode to check the layout without a group.
- No external libraries.

## Installation

1. Copy the `HealTide` folder into:
   `World of Warcraft\_forever_\Interface\AddOns\HealTide`
2. `/reload`.
3. Enable **HealTide** in the addon list.
4. `/ht status` should report:
   `Prediction: OK | clamps: MaximumHealth / MissingHealth | two calculators: yes`

## Commands

| Command | Description |
|---|---|
| `/ht test` | Demo cards for 15 s: target 50% with 250 from others + 350 from you (100 overheal); you 70% with 300 incoming. |
| `/ht live` | Real values for 10 s. |
| `/ht stop` | Hide demo cards. |
| `/ht unlock` / `/ht lock` | Drag/lock the cards. |
| `/ht outgoing` / `/ht incoming` | Toggle each card type. |
| `/ht healsonly` | Toggle the heal-spell filter. |
| `/ht width 220` | Card width (120–500). |
| `/ht height 16` | Card height (10–40). |
| `/ht spacing 2` | Gap between cards (0–20). |
| `/ht reset` | Defaults. |
| `/ht status` | API, clamp, settings, diagnostics. |
| `/ht secrets` | Secret-value diagnostics (health, calculator, incoming values). |

## Compatibility

- World of Warcraft: Forever 1.60.x, interface `16001`.
- Not compatible with Retail or Classic clients without a separate port.
- No dependencies.

## Known limitations

- **Direct heals only.** Forever's native prediction does not include HoTs. HealTide does not guess them; other players' HoTs are not exposed in combat.
- The client marks health and heal prediction values as secret, even outside combat. The cards render natively; amounts and severity colors use the client's formatter when available, otherwise numeric text stays hidden.
- AoE heals: extra target cards appear when the player's contribution is readable; otherwise the current cast target is shown.
- This is a floating HUD, not a replacement for VuhDo, HealBot, Grid2, or HealForever.

## Development

Offline tests (Lua 5.1):

```sh
lua tests/test_healtide.lua
```

Build the release zip:

```powershell
powershell -ExecutionPolicy Bypass -File build.ps1
```

The zip is written to `dist/HealTide-<version>.zip` and contains `HealTide/HealTide.toc`, `HealTide/HealTide.lua`, `HealTide/README_FR.md`, and `HealTide/LICENSE`.

The CI workflow runs the Lua syntax check and offline tests on pushes to `main` and on pull requests. Tags are handled by the `Release` workflow, which also runs the tests.

## Release

The `Release` workflow runs on a tag like `v1.0.0`:

1. checks `## Version` in `HealTide.toc`;
2. runs the tests;
3. builds `dist/HealTide-<version>.zip`;
4. creates a GitHub Release;
5. uploads to CurseForge **only if** the repository variable `CF_PUBLISH` is `true`.

CurseForge project creation is manual. Set:

- secret `CF_API_TOKEN` — https://www.curseforge.com/account/api-tokens
- variable `CF_PROJECT_ID`
- variable `CF_GAME_VERSION` (default `1.60.1`)
- variable `CF_PUBLISH` (`true` to enable upload)

Then:

```sh
git tag v1.0.0
git push origin v1.0.0
```

Without `CF_PUBLISH`, the GitHub Release is still created and the zip can be uploaded manually.

## License

MIT — see `LICENSE`.
