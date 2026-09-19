# Version 0.0.3

## Changes

- Updated the Flutter version to `0.0.3+3`.
- Added a reusable `LinkMetadataService` that reads standard Open Graph,
  Twitter-card, HTML title, and description metadata directly from the destination
  page. It has an eight-second timeout, a 512 KiB HTML limit, a three-redirect
  limit, content-type checks, URL validation, and DNS checks that reject local,
  private, link-local, reserved, and nonstandard-port destinations. Redirects are
  validated again. It sends no URL or page content to a third-party metadata API.
- Kept the save path fast: the Firestore item is queued first, then metadata is
  fetched and stored in the background. A per-repository in-flight set prevents
  concurrent duplicate requests for one item. `metadataStatus` prevents normal
  timeline rebuilds from refetching previews. Failure produces an intentional
  stored fallback and never reverses the save.
- Extended items with optional `description`, `siteName`, `domain`, and
  `metadataStatus`. Existing nullable title/thumbnail fields remain. Deserialization
  accepts old documents without any new fields and falls back to their URL domain,
  shared text, and existing timestamps.
- Redesigned cards around source, domain, title, description/shared text,
  thumbnail, platform icon, saved time, favorite, sync state, and preview state.
  Invalid or broken image URLs collapse to a safe platform placeholder. All text
  uses bounded lines and ellipsis in the timeline.
- Added a lightweight details screen for full shared text, URL, preview, source,
  saved date, favorite, open, copy, share, and delete actions.
- Improved search with metadata fields, normalized whitespace, a clear button,
  result count, and separate empty search/date states.
- Added three first-launch onboarding screens with Skip, Continue, and Get Started.
  Completion is stored locally with `shared_preferences`, so it is not shown on
  every launch. Storage failure does not prevent entry into the app.
- Polished the empty state and profile with explicit share-sheet education,
  current plan presentation, theme controls, email, sign-out, and app version.

## Firestore and backward compatibility

New documents add nullable metadata fields and start with `metadataStatus: pending`.
Old documents remain readable and can still be favorited or deleted. The rules
accept the optional v0.0.3 fields, validate their types and lengths, require HTTPS
thumbnail URLs, and allow an owner to update only favorite/metadata fields plus
the server-controlled update timestamp. User ID and URL ownership remain fixed.

The final local rules are in `firestore.rules`. They must be deployed before
metadata updates can succeed in the configured Firebase project.

## Dependencies

- `html ^0.15.7` for standards-based HTML metadata parsing.
- `shared_preferences ^2.5.5` for local onboarding completion.

Networking uses Dart's `HttpClient`; no metadata proxy, unofficial social API, or
extra HTTP dependency was added.

## Preview reliability

Generic public HTML pages with server-rendered Open Graph or ordinary meta tags
are the reliable path. Public YouTube and Reddit pages may provide useful metadata,
subject to their current response and regional/network policies. Instagram,
TikTok, Facebook, X/Twitter, shortened links, bot-protected sites, JavaScript-only
pages, consent pages, authenticated pages, and sites that reject the client may
fall back to platform name, domain, shared text, and original URL. No authentication,
restriction bypass, media download, or private social-content scraping is used.

## Files changed

- `pubspec.yaml`, `pubspec.lock`
- `firestore.rules`
- `lib/main.dart`
- `lib/core/services/link_metadata_service.dart`
- `lib/features/onboarding/presentation/onboarding_page.dart`
- `lib/features/profile/presentation/profile_page.dart`
- `lib/features/saved_items/data/saved_items_repository.dart`
- `lib/features/saved_items/domain/saved_item.dart`
- `lib/features/saved_items/presentation/pages/library_page.dart`
- `lib/features/saved_items/presentation/pages/saved_item_details_page.dart`
- `lib/features/saved_items/presentation/widgets/saved_item_card.dart`
- `README.md`, `VALIDATION.md`, `V0_0_3_REPORT.md`

## Validation

Commands run:

```powershell
flutter pub add html shared_preferences
dart format lib
flutter analyze
dart format lib/features/saved_items/domain/saved_item.dart lib/features/saved_items/data/saved_items_repository.dart lib/features/saved_items/presentation/pages/saved_item_details_page.dart
flutter analyze
git diff --check
```

The final `flutter analyze` passed with no issues. `git diff --check` passed apart
from informational Windows line-ending warnings. Per explicit instruction, no test
was added or run and no Android/iOS build was run. Real-device acceptance,
Firestore emulator rules, and live metadata behavior were therefore not claimed.

## Remaining limitations and suggested 0.0.4 scope

Metadata runs on the client and depends on each destination's public HTML and
network policy. Preview image hosts are remote and may be slow or disappear.
Metadata failure is marked unavailable rather than retried forever; users can
still open, search, favorite, share, or delete the saved item. Existing v0.0.2
records are not bulk-enriched, avoiding surprise network requests and migrations.
Onboarding completion is device-local. Search still covers the loaded 100-item
batches rather than a server-side full-library index.

Recommended 0.0.4 scope: use real-device findings to tune preview compatibility,
add an explicit user-triggered preview retry if it proves useful, persist theme
choice, and complete production app identity/signing. No 0.0.4 work was started.
