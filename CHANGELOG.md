# HealTide

## Unreleased

- During a self-heal, the incoming card now steps aside and returns with its health bar when the self-heal window ends, including in solo play.
- Other players' heals are drawn on the **You** card as a thinner (40% height) light-blue strip while you are self-healing; your own heal keeps the full-height green segment.
- The incoming card keeps its normal health + received-heal layout; the minimal-ribbon experiment is removed.
- The strip is secret-value safe: secret heal values feed native StatusBars and the orange overheal overlay uses `SetAlphaFromBoolean`.
- No solo/group assumption remains: players outside your group can heal you.
- Offline tests cover the self-heal strip, the return of the incoming card, and secret values.

## 1.0.0

- Cast tracking now follows the active cast GUID; instant, foreign, or non-heal casts no longer steal a hard-cast heal card.
- `OnUpdate` and slash commands are protected by `pcall` to avoid per-frame error spam.
- Incoming other-heal amounts use the unclamped healer total; long incoming predictions are refreshed instead of expiring at 3 s.
- Overheal cap alpha resets correctly, health/heal colors read current health, and color access is protected.
- A new cast clears the old `hadHeal` state; `/ht outgoing` hides active cards and blocks new ones.
- `LICENSE` is included in release and CurseForge packages; release uploads fail on missing files or HTTP errors.
- CI runs on `main`/pull requests only and uses `actions/checkout@v5`.
- New heal prediction HUD for World of Warcraft: Forever (interface 16001), with one cast-style bar per card.
- Native prediction through `UnitGetDetailedHealPrediction` / `UnitHealPredictionCalculator`.
- Cast-style bar: health fill plus a heal extension, with the name and amount inside the bar.
- Thin 220 × 16 default, with 1px inset, compact small fonts, a black border, and cast-bar sparks.
- Heal extension colored green → yellow → orange → red by overheal severity.
- Heal extension, bar border, and end cap share the overheal color.
- Heal extension continues past the bar to show overheal, proportional and secret-value safe (red end cap in combat).
- Cards now shorten their timeout as soon as the prediction is consumed, instead of waiting for the full prediction lifetime.
- Resolved casts ignore stale `UnitCastingInfo` and use a 0.6s tail for later prediction events.
- Self-heals update the outgoing **You** card; the incoming card independently shows other players' heals, including during a self-heal.
- Outgoing target cards (plus AoE cards when readable) and an incoming card for the player.
- Secret-value safe StatusBars and hidden numeric text when values are secret.
- Demo mode (`/ht test`), live mode (`/ht live`), movement lock, size/spacing settings, heals-only toggle, diagnostics.
- Offline Lua test harness and tag-driven GitHub/CurseForge release workflow.
