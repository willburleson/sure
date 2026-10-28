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

## Moving to a new upstream release

```sh
git fetch upstream --tags
git rebase --onto vX.Y.Z <old tag> will   # e.g. --onto v0.7.6 v0.7.5-hotfix.1
git push --force-with-lease origin will
```

Wait for the "Will image" workflow, then deploy the printed tag from `sure-oci`.
