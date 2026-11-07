# AidVise — Web

**Repository:** `AI-Hub-Web`
**Component:** Public website and web platform
**Release:** Alpha 3.4.0

---

## Overview

This repository holds the two web properties, deliberately kept separate:

| Part | Location | Audience | Login | Hosting |
|---|---|---|---|---|
| Home page | repository root (`index.html`, `assets/`) | Public: about, pricing | None | GitHub Pages, `moonjtech.com` |
| Platform | `platform/` (Flutter web) | Administrators today; job seekers and employers later | Required | Its own address, e.g. `admin.moonjtech.com` |

The home page is plain HTML so it loads instantly and is readable by search
engines. The platform is an application and is never published as part of
the home page (`_config.yml` excludes it from GitHub Pages).

The platform shares no code with the mobile application (`AI-Hub-Frontend`).
Both talk to the same backend (`AI-Hub-Backend`), which enforces every
permission; the platform's admin checks only decide what to show.

## Platform structure

```
platform/lib/
  main.dart     entry point; today it opens the admin gate
  shared/       api client, login and session, app shell, theme, cards, forms
  admin/        users, job listings, plans, vendor approvals, failed resumes
  user/         (planned) job seeker area
  vendor/       (planned) employer area
```

Role folders import from `shared/` and never from each other, so an area
can change or be removed without touching the others.

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
| Alpha 3.4.0 | 2026-11-07 | Web platform introduced in `platform/`, a Flutter web application organised by role (`shared/`, `admin/`; `user/` and `vendor/` planned). The administration panel moved here from the mobile project and no longer shares code with it: users, job listings, plans and store prices, vendor approvals and failed resumes. The home page is unchanged and excludes the platform from its published site. |
