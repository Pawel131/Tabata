# Tabata

A Tabata / interval timer in two versions:

- **iOS app** (`Tabata/`, SwiftUI): open `Tabata.xcodeproj` in Xcode.
- **Web app** (`web/`, installable PWA): runs in any browser and can be added to the iPhone home screen. See [Web app (PWA)](#web-app-pwa).

## Features

- **Configurable workout**: work time, rest time, rounds, sets, rest between sets, and a "get ready" countdown. Built-in presets (Classic 20/10 × 8, Beginner, Double, Endurance, HIIT 45/15). Your settings are remembered.
- **Live workout screen**: full-screen color per phase (get ready / work / rest / set rest), a large countdown, a ring for the current interval, round dots, and overall elapsed and remaining time.
- **Controls**: pause/resume, skip interval, end early (asks you to confirm).
- **Cues**: 3-2-1 countdown beeps, spoken announcements ("Round 3. Work!", "Rest", "Last round"), and haptics. Each can be turned off. Audio mixes with your music.
- **Accurate timing**: the timer runs from wall-clock end times, not tick counts, so it stays correct if the app is briefly in the background. The screen stays awake during a workout.
- **Progress tracking**: each workout is saved with SwiftData. The Progress tab shows total workouts, day streak, total time, rounds, workouts this week, completion rate, a chart of minutes trained over the last 7 days, and a full history you can swipe to delete.

## Requirements

- Xcode 16 or later
- iOS 17.0 or later

## Running

1. Open `Tabata.xcodeproj` in Xcode.
2. Pick an iPhone simulator or your device.
3. To run on a device, choose your team under *Signing & Capabilities* and change the bundle identifier (`com.example.tabata`) if needed.
4. Press ⌘R.

## Project layout

```
Tabata/
  App/TabataApp.swift          App entry point and tab view
  Models/WorkoutConfig.swift   Workout settings, phase list, presets
  Models/WorkoutRecord.swift   SwiftData history model and progress stats
  Timer/TabataEngine.swift     Timer state machine
  Timer/WorkoutFeedback.swift  Beeps, voice, and haptics
  Views/SetupView.swift        Settings screen
  Views/WorkoutView.swift      Live workout and summary screens
  Views/HistoryView.swift      Progress stats, chart, and history
  Views/PhaseStyle.swift       Phase colors and progress ring
```

The Xcode project uses a synchronized folder group, so any file you add under `Tabata/` is included in the build automatically.

## Web app (PWA)

`web/` is a static site with no build step and no dependencies: `index.html`, `styles.css`, `app.js`, a service worker (`sw.js`) for offline use, a web app manifest, and icons. It has the same features as the iOS app. Workouts are saved on the device (`localStorage`), and **Export / Import** on the Progress tab moves your history between devices as a JSON file.

### Run it locally

```
npm start            # serves ./web on http://localhost:3000
```

The service worker and "Add to Home Screen" need HTTPS (localhost is exempt), so test installing on a real phone after deploying.

### Install on iPhone

1. Open the deployed URL in **Safari**.
2. Tap **Share → Add to Home Screen**.
3. Launch it from the home screen. It runs full screen and works offline.

### Hosting

The app is plain static files, so any static host works. No server or database is needed.

| Host | Cost | Setup | Notes |
| --- | --- | --- | --- |
| **GitHub Pages** (recommended) | Free | Workflow included | Code is already on GitHub. HTTPS included. |
| Netlify / Cloudflare Pages | Free tier | Point at the repo, publish directory `web` | Custom domains and preview deploys. |
| AWS Amplify Hosting | Free tier, then pay per use | Connect repo, output directory `web` | Easiest AWS option. |
| AWS S3 + CloudFront | Cents per month | Manual setup | Most control, most work. |
| Heroku / Render | Heroku from about $5/month (no free tier) | `npm start` runs `server.js` | Only worth it if you later add a backend. |

**GitHub Pages**
1. Merge this branch into `main`.
2. In the repo, go to **Settings → Pages → Build and deployment** and set **Source** to **GitHub Actions**.
3. The workflow in `.github/workflows/pages.yml` deploys `web/` on every push to `main` that changes it. Your app will be at `https://<user>.github.io/Tabata/`.

**Heroku**
```
heroku create my-tabata
git push heroku main
```
Heroku detects Node from `package.json` and runs `npm start`. `server.js` serves `web/` and redirects HTTP to HTTPS.

**AWS Amplify**
In the Amplify console choose **Host web app**, connect the GitHub repo and branch, and set the build output directory to `web` with no build command.

### Updating the installed app

After you change files in `web/`, bump `VERSION` in `web/sw.js` (for example `tabata-v2`). Installed apps get the new version the next time they're opened with a connection, and show it on the launch after that.
