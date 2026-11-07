# AidVise — Web

**Repository:** `AI-Hub-Web`
**Component:** Public website and web platform
**Release:** Alpha 3.5.0

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

### Differences from the mobile application

The job seeker and employer areas started as copies of the mobile screens
and are kept identical for now, except where a browser cannot do what a
phone does:

| Mobile | Web |
|---|---|
| Native PDF view from a temporary file | The browser's own PDF viewer; downloads through the browser |
| File picker returns a path; uploads read the file | File picker returns bytes; uploads send them |
| Apple / Google in-app purchase, demo activation when no store | Demo activation only, until web payments (e.g. Stripe) are added |
| Opens Apple subscription settings on cancel | Tells mobile subscribers to cancel in their store settings |

The two codebases share no code, so the web can be redesigned independently.

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
| Alpha 3.5.0 | 2026-11-07 | Job seeker and employer areas migrated from the mobile application into `platform/lib/user/` and `platform/lib/vendor/`, identical in behaviour, so the whole product now runs in the browser. One login serves all three account types; a new gate opens the admin panel, the employer workspace or the job seeker home. Changes forced by the browser only: resumes display in the browser's PDF viewer and download through it, avatar and resume uploads send file bytes, and in-app purchase is removed in favour of the existing demo activation. Employers read applicant resumes in a shared viewer, so the employer area no longer depends on the job seeker area. Mobile tests ported. |
| Alpha 3.4.0 | 2026-11-07 | Web platform introduced in `platform/`, a Flutter web application organised by role (`shared/`, `admin/`; `user/` and `vendor/` planned). The administration panel moved here from the mobile project and no longer shares code with it: users, job listings, plans and store prices, vendor approvals and failed resumes. The home page is unchanged and excludes the platform from its published site. |
