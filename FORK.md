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

## Moving to a new upstream release

```sh
git fetch upstream --tags
git rebase --onto vX.Y.Z <old tag> will   # e.g. --onto v0.7.6 v0.7.5-hotfix.1
git push --force-with-lease origin will
```

Wait for the "Will image" workflow, then deploy the printed tag from `sure-oci`.
