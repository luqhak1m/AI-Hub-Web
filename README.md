# AidVise — Web

**Repository:** `AI-Hub-Web`
**Component:** Public website and web platform
**Release:** Alpha 3.9.0

---

## Overview

This repository holds the two web properties, deliberately kept separate:

| Part | Location | Audience | Login | Hosting |
|---|---|---|---|---|
| Home page | repository root (`index.html`, `assets/`) | Public: about, pricing | None | GitHub Pages, `moonjtech.com` |
| Platform | `platform/` (Flutter web) | Job seekers, employers and administrators | Required | Its own address, e.g. `app.moonjtech.com` |

The home page is plain HTML so it loads instantly and is readable by search
engines. The platform is an application and is never published as part of
the home page (`_config.yml` excludes it from GitHub Pages).

The platform shares no code with the mobile application (`AI-Hub-Frontend`).
Both talk to the same backend (`AI-Hub-Backend`), which enforces every
permission; the platform's admin checks only decide what to show.

## Platform structure

```
platform/lib/
  main.dart      entry point
  app_gate.dart  verifies the session and opens the area for the account type
  shared/        api client, login, registration, session, app shell, theme,
                 cards, sheets, PDF viewer, listing form
  user/          job seeker: assessment, results, advisor, resumes, jobs,
                 applications, notifications, career progress, subscription
  vendor/        employer: listings, applicants, screening assessments,
                 interview preparation
  admin/         users, job listings, plans, vendor approvals, failed resumes
```

Role folders import from `shared/` and never from each other, so an area
can change or be removed without touching the others. `app_gate.dart` is the
only file that knows every area.

Everyone signs in at the same login. Administrators land in the admin
panel, approved employers in the employer workspace, everyone else in the
job seeker home.

### Design

The web platform has its own design, taken one-to-one from the layout drafts
in `draft/` (`draft/mix.html`, light theme). It shares nothing with the
mobile app's look.

| Part | Where |
|---|---|
| Colours, fonts (Bricolage Grotesque, Figtree), type scale, radii | `shared/ui/tokens.dart` |
| Pills, chips, buttons, logos, stat boxes, score bars, list rows | `shared/ui/components.dart` |
| Sidebar shell, list + detail, board, table, page padding | `shared/ui/layout.dart` |

#### Changing and extending the design

The tokens are interfaces, published to the widget tree as a Flutter
`ThemeExtension`; components read them with `context.ui`, and the Material
theme (`Ui.theme(tokens)`) is built from the same tokens, so stock buttons,
inputs and dialogs follow too.

| To… | Do this |
|---|---|
| Change a colour everywhere | Edit it in `DraftLightPalette` |
| Change fonts or the type scale | Edit `DraftTypography` |
| Add a palette (brand variant, dark mode) | Implement `UiPalette`; `DraftDarkPalette` is ready |
| Switch the whole app | `AppFrame(tokens: UiTokens.dark)` |
| Restyle one area only | Wrap it in `UiScope(tokens: …)`; everything inside follows |
| One-off button or pill colours | `UiButton(style: UiButtonStyle(...))`, `UiButtonStyle.danger(context.ui)`, `Pill(style: PillStyle(...))` |

New code reads `context.ui`. The static `Ui.*` constants remain for `const`
widgets and older screens; they equal the light palette (checked by
`test/design_tokens_test.dart`).

| Page | Layout |
|---|---|
| Home | Sidebar dashboard: greeting, reminder, four tool tiles, recommended jobs |
| Jobs | List + detail with your match on every job and a "why you match" breakdown |
| Applications | Pipeline board, one column per stage |
| Resumes | Table with this month's quota |
| Assessment | List + detail: matched careers and your six interest scores |
| Notifications | List + detail |
| Employer applicants | Table with score bars, skills matched, status and reschedule requests |

Below 860 px the sidebar becomes a bar across the top and every layout
stacks to one column, as in the drafts. The drafts' dark palette is the
planned dark mode.

Every other screen uses the same system: the admin panel and employer area
sit in the same steel sidebar; employer listings and admin users and
listings are tables; the template picker is a grid of full previews;
interview prep shows every card at once; buttons, inputs, dialogs, sheets and
cards are drawn from the tokens through the Material theme
(`Ui.theme()`), the shared card (`shared/widgets/app_card.dart`) and the
detail sheet (`shared/widgets/detail_sheet.dart`). `AppTheme` remains only
as aliases of the tokens for older code.

## Administration panel

| Section | Capabilities |
|---|---|
| Users | Search by name, username or company; filter by role; view plan, usage and activity; change plan with optional end date; reset password; deactivate and reactivate |
| Job Listings | Search by title or company; edit any listing; hide and show |
| Plans | Name, description, features, quotas, App Store and Google Play product identifiers and prices; store status per plan; resend a failed price; run the store check |
| Vendor Approvals | Approve or reject employer accounts |
| Failed Resumes | Inspect and retry failed resume generations |

Every change that affects users asks for confirmation. Only accounts with
administrator rights can sign in.

## How to Run

### Home page

Open `index.html`, or serve the root: `python3 -m http.server`.
Pushing to `main` publishes it.

### Platform

```bash
cd platform
flutter pub get
flutter run -d chrome                                   # against http://localhost:8000
flutter build web --dart-define=BASE_HOST=https://api.example.com
```

`build/web` is a static site and can be hosted anywhere (Firebase Hosting,
Cloudflare Pages, Netlify, or a second GitHub Pages repository). Add the
platform's address to the backend's `CORS_ORIGINS`.

### Verification

```bash
cd platform
flutter analyze
flutter test
```

## Version History

| Version | Date | Summary |
|---|---|---|
| Alpha 3.9.0 | 2026-11-08 | Design tokens made extensible. Colours and type are now interfaces (`UiPalette`, `UiTypography`) with the drafts' light and dark palettes as implementations, combined in `UiTokens` and published to the widget tree as a ThemeExtension. Components, the shared card and detail sheet, the drafted pages and the app frame read tokens from context, so `UiScope` restyles any subtree and `AppFrame(tokens:)` switches the whole app; the Material theme is generated from the same tokens. Button and pill colours became style objects (`UiButtonStyle`, `PillStyle`) for special cases, and the banner gradient moved into the palette. No visual change. Seven tests cover overrides, scoping and the dark palette. |
| Alpha 3.8.0 | 2026-11-08 | The rest of the web platform moved to the draft design system. Material buttons, inputs, dialogs, sheets, tabs, snackbars and menus are drawn from the tokens through the theme; the shared card and detail sheet were redrawn in the draft style, and hard-coded colours were mapped to tokens across 33 files. Admin panel moved onto the draft sidebar with draft page headings, and its users and listings became tables. Employer home rebuilt as a dashboard and employer listings as a table. Template picker became a preview grid, interview prep shows all cards at once, profile actions moved into the page header, career statistics became a stats row, registration matches the login card, and full-width mobile buttons were reduced to standard buttons. Finishing the assessment now returns to the Assessment page. Section first pages no longer show a back arrow that could empty the section. Seven obsolete widgets and screens removed. |
| Alpha 3.7.0 | 2026-11-08 | Web platform redesigned to match the layout drafts exactly, independent of the mobile app. A design system (`shared/ui/`) carries the drafts' colours, Bricolage Grotesque and Figtree type, components and layouts; the job seeker home, jobs, applications, resumes, assessment and notifications, and the employer applicants page, are rebuilt on it, with the drafts' steel sidebar for both job seekers and employers and a top bar on narrow windows. Jobs show the signed-in person's match on every listing and a component-by-component breakdown, from two new backend endpoints. Login restyled to match. Replaced mobile-derived screens and the background image removed. Fixed sections being rebuilt (and refetching) whenever the sidebar redrew. |
| Alpha 3.6.0 | 2026-11-08 | Wide-screen layouts for the platform, styling unchanged. The sidebar stays open beside the page from 1,000 px. Home becomes a dashboard with four tool tiles across and a recommended-jobs row, and its tiles open their sections; jobs, assessment results and notifications become list + detail; applications open on a pipeline board with one column per stage; resumes and employer applicants become tables. Every page keeps its mobile layout when narrow, and adapts live when the window is resized. Detail views are defined once and shown either as a sheet or inline. Card action rows wrap instead of overflowing. Layout drafts kept in `draft/`. |
| Alpha 3.5.0 | 2026-11-07 | Job seeker and employer areas migrated from the mobile application into `platform/lib/user/` and `platform/lib/vendor/`, identical in behaviour, so the whole product now runs in the browser. One login serves all three account types; a new gate opens the admin panel, the employer workspace or the job seeker home. Changes forced by the browser only: resumes display in the browser's PDF viewer and download through it, avatar and resume uploads send file bytes, and in-app purchase is removed in favour of the existing demo activation. Employers read applicant resumes in a shared viewer, so the employer area no longer depends on the job seeker area. Mobile tests ported. |
| Alpha 3.4.0 | 2026-11-07 | Web platform introduced in `platform/`, a Flutter web application organised by role (`shared/`, `admin/`; `user/` and `vendor/` planned). The administration panel moved here from the mobile project and no longer shares code with it: users, job listings, plans and store prices, vendor approvals and failed resumes. The home page is unchanged and excludes the platform from its published site. |
