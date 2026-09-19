# Version 0.0.3

## Changes

- Updated the Flutter version to `0.0.3+3`.
- Added a reusable `LinkMetadataService` that uses `metadata_fetch` to read
  Open Graph, Twitter Card, JSON-LD, HTML title, and description metadata from the destination
  page. It has an eight-second timeout, a 512 KiB HTML limit, a three-redirect
  limit, content-type checks, URL validation, and DNS checks that reject local,
  private, link-local, reserved, and nonstandard-port destinations. Redirects are
  validated again. It sends no URL or page content to a third-party metadata API.
- Kept the save path fast: the backward-compatible base Firestore item is queued
  first, then metadata is fetched and stored after server confirmation. A
  per-repository in-flight set prevents
  concurrent duplicate requests for one item. `metadataStatus` prevents normal
  timeline rebuilds from refetching previews. Failure produces an intentional
  stored fallback and never reverses the save.
- Extended items with optional `description`, `siteName`, `domain`, and
  `metadataStatus`. Existing nullable title/thumbnail fields remain. Deserialization
  accepts old documents without any new fields and falls back to their URL domain,
  shared text, and existing timestamps.
- Redesigned cards as compact rows with an 84-pixel left thumbnail and title,
  source/domain, saved time, favorite, and actions on the right. Invalid, slow,
  missing, or broken images show a platform placeholder. Titles use two lines and
  ellipsis, and stored raw URLs no longer dominate preview cards.
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

New documents first use the v0.0.2 schema, then add nullable metadata fields and
`metadataStatus` in a separate background update. This keeps the core save working
during a staged rules rollout; preview writes still require the v0.0.3 rules.
Old documents remain readable and can still be favorited or deleted. The rules
accept the optional v0.0.3 fields, validate their types and lengths, require HTTPS
thumbnail URLs, and allow an owner to update only favorite/metadata fields plus
the server-controlled update timestamp. User ID and URL ownership remain fixed.

The final local rules are in `firestore.rules`. They must be deployed before
metadata updates can succeed in the configured Firebase project.

## Dependencies

- `html ^0.15.7` for standards-based HTML metadata parsing.
- `metadata_fetch ^0.4.2` for ordered Open Graph, Twitter Card, JSON-LD, and HTML parsing.
- `shared_preferences ^2.5.5` for local onboarding completion.

Networking uses the existing guarded Dart `HttpClient` layer rather than the
package's convenience fetch, preserving timeout, size, redirect, and private-host
checks. No metadata proxy or unofficial private API was added.

## Preview reliability

Generic public HTML pages with server-rendered Open Graph, Twitter Card, JSON-LD,
or ordinary meta tags are the reliable path. YouTube and TikTok first use their
public oEmbed endpoints and generic metadata fills missing fields. Reddit uses
generic public metadata. Instagram, Facebook, X/Twitter, shortened links,
bot-protected sites, JavaScript-only
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
- `lib/features/saved_items/presentation/bloc/saved_items_bloc.dart`
- `lib/features/saved_items/presentation/pages/library_page.dart`
- `lib/features/saved_items/presentation/pages/saved_item_details_page.dart`
- `lib/features/saved_items/presentation/widgets/saved_item_card.dart`
- `README.md`, `VALIDATION.md`, `V0_0_3_REPORT.md`
- `test/link_metadata_service_test.dart`
- `test/saved_item_compatibility_test.dart`
- `test/saved_item_card_test.dart`, `test/content_test.dart`

## Validation

Commands run:

```powershell
flutter pub add html shared_preferences
flutter pub add metadata_fetch
dart format lib
dart format lib test
flutter pub get
flutter analyze
dart format lib/features/saved_items/domain/saved_item.dart lib/features/saved_items/data/saved_items_repository.dart lib/features/saved_items/presentation/pages/saved_item_details_page.dart
flutter analyze
flutter test
dart format lib/features/saved_items/presentation/bloc/saved_items_bloc.dart
flutter test
flutter analyze
flutter build apk --debug
git diff --check
```

The final `flutter analyze` passed with no issues. All 29 tests passed. The first
test run exposed an offline share retry regression; the session guard was fixed
and the full suite passed on rerun. The Android debug build passed and produced
`build/app/outputs/flutter-apk/app-debug.apk`. A non-failing future Kotlin plugin
migration warning remains for the existing Firebase plugins. Real-device acceptance,
Firestore emulator rules, and live metadata behavior were not claimed.

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
