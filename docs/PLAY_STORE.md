# Putting CLE Portal on Google Play

The Android app is your website in an app frame (a "Trusted Web Activity").
It runs your live site, so every change you merge on GitHub reaches the app
too, with no app update needed.

## What is already done

- The site is an installable app: `manifest.webmanifest`, icons in `icons/`,
  and an offline helper `sw.js`.
- Learners can delete their own account (Account → Delete my account), which
  Google Play requires for apps with sign-up.
- A privacy policy draft: `privacy.html`. Its deletion steps are at
  `privacy.html#delete`.

## What you need

1. **The site live at a web address you control, at the top of the domain.**
   The app proves it belongs to your site with a file at
   `https://YOUR-DOMAIN/.well-known/assetlinks.json`. That file must be at the
   root of the domain, so a GitHub Pages address like
   `gowthamadam1-lgtm.github.io/customs-logistics-edu-portal/` does not work
   for this. Use your own domain pointed at GitHub Pages.
2. **A Google Play developer account:** a one-time fee of US $25 and an
   identity check, at https://play.google.com/console.
3. **Finish `privacy.html`:** fill in your name and contact email, check every
   line, and remove the yellow draft notice.

## Steps

1. **Build the app package.** Open https://www.pwabuilder.com, enter your site
   address, choose **Package for stores → Android → Generate package**, and
   download the zip. It contains the `.aab` file you upload to Play, an
   `assetlinks.json` file, and a **signing key**. Keep the signing key and its
   passwords somewhere safe: you need them for every future update.
2. **Publish `assetlinks.json`.** Put it in the repository at
   `.well-known/assetlinks.json` and merge. After you upload the app,
   Play Console shows a second fingerprint under **Test and release → App
   integrity → App signing key certificate (SHA-256)**; add it to the same
   file. Without it, the app opens with a browser address bar at the top.
3. **Create the app in Play Console** and fill in:
   - Store listing: app name, short description (up to 80 characters), full
     description (up to 4,000), app icon 512 × 512 (`icons/icon-512.png`),
     feature graphic 1024 × 500, and at least two phone screenshots.
   - Privacy policy: `https://YOUR-DOMAIN/privacy.html`
   - Data safety: answer from the privacy policy (account details, profile
     photo, learning progress, uploaded files; nothing shared for advertising;
     users can delete their data).
   - Account deletion URL: `https://YOUR-DOMAIN/privacy.html#delete`
   - App access: the app needs a login, so give Google's reviewers a test
     learner account (username and password) that is already approved.
   - Content rating questionnaire and target audience (adults).
4. **Test, then release.** New personal developer accounts must run a closed
   test with a minimum number of testers for a set period before they can
   publish to everyone; Play Console shows the current requirement on your
   dashboard. Upload the `.aab` to the closed test track first, then promote it
   to **Production** when Play allows it.
