# CourtLine Full

CourtLine Full pairs an Android tablet or iPad with a small Windows Export Runner. The tablet manages four courts, runs match automation and sends vMix commands. The runner keeps the Scoreholio session and event admin pages on the production PC and writes the export files there.

## First test

1. Install and open **CourtLine Full Export Runner** on Windows. Choose **Open Scoreholio** and sign in. Close the Scoreholio window when you finish.
2. Connect the tablet and PC to the same trusted local network. Choose **Show Pairing Code** on the runner. In the tablet's **Settings**, scan the QR code or paste the address copied from the runner.
3. In Scoreholio Remote Mode, use **Copy URL** for the court you want. On the tablet, choose a court, open **Edit court**, paste the scoreboard URL and save. Each slot has its own export subfolder, from `event-1` through `event-4`.
4. Press **Export Stats Now** on the tablet. Use **Event stats & logs** on the runner to inspect the Scoreholio admin page.
5. Save the vMix PC's local address and port in tablet **Settings**. Add a shortcut and start monitoring under **Automation**. Dry run starts enabled for each new court. Keep the tablet app open during monitoring. Start monitoring again after it stops on a disconnect or when the app leaves the foreground.

The export folder contains ScoreMagic and available roster and standings CSVs, consolidated player stats, and `SinglesMatchup.xml` and `DoublesMatchup.xml` when the court lineup can be confirmed. Tournament and player fields sit directly under `/Matchup`. Pairing addresses contain a key. Use **Reset Pairing** on Windows to replace it.

## iPad development build

Extract the iOS Xcode source ZIP on a Mac. In its `mobile` folder, run `npm ci` and `npm run ios:sync`. Open `mobile/ios/App/App.xcodeproj` in Xcode, choose a signing team for `com.courtline.full`, and run on a development iPad. The ZIP includes the shared sources and a synced web bundle. Android uses the separate application ID `com.courtline.full`.

CourtLine Full uses its own `full-v*` prerelease tags. Check the [repository releases](https://github.com/dswartzlander/Courtline/releases) for published test downloads.
