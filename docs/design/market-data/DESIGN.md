# Outside data — exchange rates, cost of living, housing

## Problem
Three requested pages need numbers the ledger cannot produce: what a currency
is worth, what a city costs, what a neighbourhood's houses sell for. Every one
of them breaks the "no network" default, so each needs a source that is free,
keyless where possible, and carries nothing about the user.

## The rule this follows
A request may leave the device only if it is: (a) triggered by opening the
page, not by a background job; (b) cached so a second visit costs nothing;
(c) made of public parameters only — a currency pair, a city name — never a
balance, a payee, or an account. Anything a provider could log must be
information the user would put in a search box anyway.

## Exchange rates (shipped)
- **Source**: ECB daily reference rates via `api.frankfurter.app`. No key, no
  account, https, one request returns five years.
- **Cache**: `app_settings` key `fx_series:<from>:<to>`, refreshed at most
  once a day, written after the page has already rendered from cache.
- **Page**: converter, then the same pair over 1M/1Y/5Y with high, low,
  average and today-against-average — the question a converter cannot answer.
- Mid-market rates are labelled as such: a bank's rate will be worse, and that
  gap is the fee.

## Cost of living (shipped)
No free keyless API exists: Numbeo's is paid per call and its terms forbid
scraping, Teleport's is dead. So the page carries two kinds of number and
never confuses them.

- **Shipped table** — 17 cities, eight monthly buckets, each in the city's own
  currency, compiled from published rent/price surveys and stamped with the
  date it was compiled (`market/costOfLiving.ts`).
- **"Ask AI for a newer read"** — one button, using the AI connection the user
  already has. The reply must parse as a bare JSON object or it is discarded;
  what survives is stored *beside* the shipped figures with the model's name
  and the day it was asked. Its freshness ends at that model's training
  cutoff, which nobody can pin down and the user cannot specify — the page
  says so rather than implying a date. One tap, one city; nothing automatic.
- **The exact half is the user's own**: six-month average spending in the
  categories they map to each bucket, from their own ledger.
- **Conversion** reuses the Exchange page's cached ECB rates — no second
  source, no second request.
- **Shape**: a scatter, city cost across against your spending up, with a
  parity diagonal. Distance from the line is the finding; paired bars would
  have buried it.
- The AI request contains a city name and a currency. Nothing about the user's
  money is in it.

## Housing — prices and a shortlist (shipped)
Two halves, and only one of them needs the internet.
- **Local half (shipped, migration 033)**: a shortlist of houses being
  considered. Each is a record with the fields a viewing actually turns up —
  address, community, asking price, beds/baths, floor area, lot, year built,
  strata fee, property tax, age of roof/furnace, orientation, school
  catchment, notes, a verdict — and a comparison view putting two or three of
  them side by side on the same rows. This is a research notebook, and it is
  the half that gets used.
- **Market half (shipped as a hand-kept log)**: benchmark price by community over time
  (Fraser Heights, Fleetwood, …). CREA/REBGV publish MLS® HPI benchmarks
  monthly as PDFs/XLS, not as an API, and their terms restrict redistribution.
  Realistic options: let the user type the benchmark they read (a logged
  series, exactly like a tracking account's value log), or read a public
  open-data feed where one exists per municipality.
- A house links to the mortgage calculators: its asking price prefills the
  purchase calculator, so "what would this one actually cost me" is one tap
  from the note.
