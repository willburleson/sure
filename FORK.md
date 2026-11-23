# willburleson/sure

Personal fork of [we-promise/sure](https://github.com/we-promise/sure) that runs on
sure.willburleson.com (deployed by the private `sure-oci` repo).

## Branches

- `main` mirrors upstream and is unused.
- `will` = an upstream release tag + the patches below. Pushing it runs upstream CI, then
  `.github/workflows/will-image.yml` publishes `ghcr.io/willburleson/sure:<version>-will.<sha>`.

## Patches

1. **Account group order** — Settings → Appearance → Dashboard gets one drag-to-reorder list of
   all account groups (Cash, Investments, Credit Cards, ...). Stored per user in
   `preferences["account_group_order"]`. `BalanceSheet#account_groups` (the sidebar's All tab)
   follows it across assets and liabilities; `BalanceSheet::ClassificationGroup` applies the
   same relative order within each side (Assets / Debts tabs, dashboard balance sheet).
2. **Cards & points** — a "Cards" nav page (`/rewards`) and a "Cards & points" dashboard
   section, per card holder: Chase 5/24 count and drop-off dates, next eligible
   application/bonus date for each catalog card under issuer rules (5/24, velocity limits,
   per-product cooldowns, lifetime and family rules), and point balances with an estimate
   (last entered balance + linked cards' spend since, at catalog earn rates). Balances are
   updated inline from either page. Tables `reward_cards` + `point_balances`; catalog, earn
   rates and rules in `config/reward_cards.yml`; logic in `app/models/reward_card/` and
   `PointBalance::Estimator`. Personal data is imported from the private `sure-oci` repo
   (`cards/`), never committed here.
   "Best to get next" ranks eligible cards by current sign-up offer (actual points or cash,
   Rakuten and credits as extras) and orders applications when one bonus would block another
   (`RewardCard::Ranking`, simulating each bonus against the issuer rules). Offers come from
   `config/reward_bonuses.yml`, which is not in the image: sure-oci mounts it and refreshes it
   weekly from Doctor of Credit with one Haiku call (`RewardCard::Bonuses`).
3. **Sidebar account rows** — each row reads institution / account name on the left and
   balance / last refresh on the right (no subtype, no per-account sparkline; the group
   header keeps its sparkline). "Last refresh" is `Account#data_refreshed_at`: SimpleFIN's
   per-account `balance_date` (when the bank data actually updated), else the last completed
   sync; manual accounts say "Manual". Formatted client-side (`refreshed_at_controller.js`)
   because the sidebar is fragment-cached; older than 3 days turns red.

## Moving to a new upstream release

```sh
git fetch upstream --tags
git rebase --onto vX.Y.Z <old tag> will   # e.g. --onto v0.7.6 v0.7.5-hotfix.1
git push --force-with-lease origin will
```

Wait for the "Will image" workflow, then deploy the printed tag from `sure-oci`.
