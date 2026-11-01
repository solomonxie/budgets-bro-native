# TestFlight external testing

App Store Connect → TestFlight → External Testing → **+** group → add the build. First build of a version goes through Beta App Review (~1 day).

## Test Information

Beta App Description (≤4000):

```
Budgets Bro is zero-based budgeting that stays on your iPhone: give every dollar a job before the month starts, record spending as it happens, and see what's left in each category. No account, no server, no bank connection — everything lives in a local database on the device.

To look around without entering your own numbers: Settings → Demo mode. It fills every screen with a year of a sample household's data, kept apart from your own; turn it off to go back.

What's in this beta:
• Budget, Spend, Accounts, Insights and Tools screens
• Mortgage, interest and payment calculators
• Import from a YNAB export (.zip)
• Backup to the device, your own iCloud Drive or S3 bucket
• Face ID / passcode app lock
• Optional AI analysis with your own API key (off by default)

Your data never leaves your phone unless you turn on a backup or an AI connection yourself.
```

Feedback Email: `you@example.com`

## Contact Information

| Field | Value |
|---|---|
| First Name | TODO |
| Last Name | TODO |
| Phone number | TODO — yours, with country code (`+1 …`) |
| Email | `you@example.com` |

## Sign-In Information

Sign-in required: **off** (no account in the app). Leave User Name / Password blank.

Review Notes: paste the App Review Notes block from [listing.md](listing.md) if present.

## Per build: What to Test

```
Everything is local, so start fresh or turn on Settings → Demo mode for sample data. Please try: adding spending on Spend, assigning money on Budget, the calculators under Tools, an iCloud Drive backup and restore, and the Face ID lock. Report anything slow, confusing or broken with a screenshot via TestFlight.
```
