# Daily Snap Duo

Daily Snap Duo is a two-person photo app. You and one friend share an invite code. Once a day, at a time neither of you picks, you both get the same prompt. Each of you takes a back-camera photo and a front-camera photo. You cannot see your friend's snap until you have posted your own.

The prompt and the clock time are computed from the invite code, so both phones agree without a server. The photos themselves sync through whichever path you turn on: this iPhone only, an AirDrop file, a small relay you run yourself, or iCloud once you have a paid developer account.

## What a day looks like

- The prompt opens at a random minute between 8:00 AM and 9:30 PM in the duo's time zone.
- The first 10 minutes count as on time. After that you can still post until the end of the day, and the snap is marked late.
- You cannot post before the prompt opens, and you cannot post after the day closes.
- If you never post, your friend's photo for that day stays sealed. The app will not show it, including on the widget.
- History keeps the days since you paired. A sealed day stays a locked frame.
- A home-screen widget shows the latest snap you are allowed to see. If your friend has posted and you have not, the widget shows a lock, not the photo.

Riley, in Settings, is a practice partner drawn on the phone. Riley posts after the window opens so you can try the reveal without a second device. You still have to post before Riley's snap appears.

## Layout

| Path | What it is |
| --- | --- |
| `DailySnapDuo/` | The iPhone app |
| `DailySnapDuoWidget/` | The home-screen widget |
| `Shared/` | Prompt schedule, reveal rule, and the App Group file format |
| `Config/Shared.xcconfig` | Bundle id prefix and the App Group id |
| `project.yml` | XcodeGen spec. This is the source of the Xcode project |
| `DailySnapDuo.xcodeproj` | Generated project, committed so you can open it without installing XcodeGen |
| `sync-server/server.py` | Optional LAN relay. No accounts and no API keys |
| `DailySnapDuoTests/` | Tests for the prompt schedule and the reveal rule |

## What you need

- A Mac with Xcode 16 or newer
- An iPhone running iOS 17 or newer
- A free Apple ID, signed in to Xcode. A paid Apple Developer Program membership is not required to install on your own phone
- A USB cable or a trusted wireless connection so Xcode can install onto the phone

The app does not ship with API keys. Local mode, the practice partner, the snap file, and the relay all run with nothing else to configure.

## Install it on your iPhone with a free Apple ID

Free Apple IDs can install apps you build in Xcode onto your own devices. Those installs expire after 7 days. Plug the phone back in and press Run again to refresh the install. They cannot upload to TestFlight or the App Store.

1. Install Xcode from the Mac App Store. Open it once and let it finish installing the extra components.
2. On the iPhone, turn on Developer Mode: Settings → Privacy & Security → Developer Mode. The phone will restart.
3. Connect the iPhone to the Mac. If the phone asks you to trust the computer, tap Trust.
4. Clone this repo and open `DailySnapDuo.xcodeproj` in Xcode. You do not need to run XcodeGen first.
5. In Xcode, open Settings → Accounts and sign in with your Apple ID. The team shows up as a Personal Team.
6. Select the Daily Snap Duo project in the navigator, then the DailySnapDuo target, then Signing & Capabilities. Check "Automatically manage signing" and set Team to your Personal Team. Do the same for the DailySnapDuoWidget target. If the test target complains, set its team too.
7. If Xcode says the bundle identifier is not available, or that it cannot register the App ID, change one line in `Config/Shared.xcconfig`:

   ```
   BUNDLE_ID_PREFIX = com.yourname
   ```

   Use something that is yours, such as `com.janesmith`. The App Group id is `group.` plus that prefix plus `.dailysnapduo`, so you only edit the prefix. Then Product → Clean Build Folder, and build again.
8. Choose your iPhone as the run destination, not a simulator, and press Run.
9. If the phone says the developer is not trusted: Settings → General → VPN & Device Management, tap your Apple ID, and tap Trust.
10. The widget is embedded in the app. To add it, long-press the Home Screen, tap the add button, and search for Daily Snap Duo. There is a small widget and a medium one.

The first launch asks for your name, then lets you start a duo or enter a friend's code. The camera permission comes up when you take the snap. Notifications are optional and are requested from the card on the Today screen.

To try the whole loop on one phone, open Settings and turn on Practice with Riley. Wait until the prompt has opened (the time is on the Today screen), post your own snap, and Riley's snap unlocks.

## If signing fails

A free Personal Team can sign this project as it is committed: an App Group for the widget, local notifications, and the camera. It cannot sign Push Notifications or iCloud. Those are not in the entitlements on purpose.

| Capability | Free Personal Team | Paid program |
| --- | --- | --- |
| Install on your own iPhone from Xcode | Yes, for 7 days at a time | Yes |
| Camera, Photos add, local notifications | Yes | Yes |
| Widget extension | Yes | Yes |
| App Groups (so the widget can show the photo) | Yes on your own devices in current Xcode | Yes |
| iCloud / CloudKit | No | Yes |
| Remote push | No. This app does not use it | Yes, if you add it later |
| TestFlight and the App Store | No | Yes |

If Xcode still reports that your Personal Team does not support App Groups:

1. Open `DailySnapDuo/DailySnapDuo.entitlements` and `DailySnapDuoWidget/DailySnapDuoWidget.entitlements`.
2. Delete the `com.apple.security.application-groups` key so each file is an empty `dict`.
3. Clean and run again.

The app, the camera, pairing, history, and reminders still work. The widget installs, but it cannot read the photo, so it asks you to open the app. Put the key back when you have a paid account if you want the photo on the Home Screen.

Do not add the Push Notifications or iCloud capability while the team is a Personal Team. Signing will fail with "Personal development teams do not support the Push Notifications and iCloud capabilities."

## Notifications

Reminders are local notifications scheduled on the phone for the next several days. Nothing is sent through Apple Push Notification service, which is why a free account is enough.

The phone notifies you when the prompt opens, and again 45 minutes later if you still have not posted. There is no background push when your friend posts. Open the app, pull to refresh, or leave it in the foreground and it will pick up a new snap from the relay or iCloud within about half a minute. With only a snap file, you see their photo when you import the file.

## Sync

Pick the mode in Settings.

### This iPhone

The default. Snaps stay in Application Support on the phone. Use this with Riley, or with the snap file below.

### Pass a snap file

On the Duo tab, tap Send snap file and AirDrop it, or save it to Files. The other phone opens the `.snapduo` file in Daily Snap Duo. The file carries the invite code, the time zone, and the photos. The reveal rule still applies on the phone that imports it: if they have not posted for that day, they will not see your photo.

You can also share the invite text. The link looks like `dailysnapduo://join/K7MQ2P`.

### Shared relay

This is the way to have two phones update themselves without a paid account and without API keys.

1. On the Mac, from the repo:

   ```
   python3 sync-server/server.py
   ```

2. The script prints a URL such as `http://192.168.1.20:8787`. If it only prints a placeholder, find the Mac's address in System Settings → Network.
3. Put both iPhones on the same Wi-Fi as the Mac. `127.0.0.1` on the phone is the phone, not the Mac.
4. On each phone, Settings → Sync → Shared relay, and paste that URL.
5. Start the duo on one phone. On the other, join with the code.

The relay stores photos in `sync-server/data/` on the Mac. The invite code is the only credential. Anyone who knows the code can fetch the photos, so keep the server on your own network and do not put it on the public internet with photos you care about. The app allows plain HTTP to local addresses. A public host should be HTTPS.

If the Mac firewall asks about Python, allow incoming connections on port 8787.

### iCloud

CloudKit is implemented against the public database, keyed by the invite code, but the iCloud entitlement is not enabled. A free Personal Team cannot sign it.

When you have a paid account:

1. In the Apple Developer portal, register an iCloud container whose id matches `CloudKitContainerID` in `DailySnapDuo/Info.plist`. With the default prefix that is `iCloud.com.anubhavgupta.dailysnapduo`. If you changed the prefix, the plist value follows it.
2. Add the iCloud capability to the DailySnapDuo target only, with CloudKit enabled and that container selected. Do not add it to the widget.
3. In Settings, choose iCloud. Both people need to be signed in to iCloud on their phones.
4. Debug builds talk to the Development environment and create the `DuoPair` and `DuoSnap` record types the first time you post. Before TestFlight, open the CloudKit console and deploy that schema to Production.

Records are fetched by id, so you do not have to mark fields queryable. Photos live in the public database. The code is the only access control, same as the relay. Treat it as a convenience, not as a private vault.

## Tests

On a Mac, open the project, select the DailySnapDuo scheme, and press Command-U. The tests check that a code always produces the same prompt and time, that the time lands between 8:00 AM and 9:30 PM, and that a friend's snap stays hidden until you post.

Without Xcode, the same hash vectors are checked by:

```
python3 scripts/check_prompt_calendar.py
```

## Regenerate the Xcode project

You only need this if you change `project.yml` or add files.

```
brew install xcodegen
xcodegen generate
```

Commit the regenerated `DailySnapDuo.xcodeproj` with your change. The spec targets iOS 17, iPhone only, Swift 5, and embeds the widget.

## TestFlight later

TestFlight requires the Apple Developer Program (paid). A free Personal Team cannot upload a build.

1. Enroll at [developer.apple.com/programs](https://developer.apple.com/programs/).
2. In Xcode, switch the Team on the app, the widget, and the tests from your Personal Team to the paid team.
3. Confirm the bundle ids. If the paid team should use a new prefix, change `BUNDLE_ID_PREFIX` in `Config/Shared.xcconfig` and clean the build.
4. Register the App Group `group.<prefix>.dailysnapduo` and enable it on both the app id and the widget id. Xcode's automatic signing usually does this when you archive, as long as the entitlements files still contain the group.
5. Leave Push Notifications off. Reminders are local.
6. Add iCloud only if you want that sync mode. See the iCloud section above, including deploying the CloudKit schema to Production.
7. Set the version and build if this is not the first upload (`MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in the xcconfig).
8. Select Any iOS Device as the destination. Product → Archive.
9. In the Organizer, Distribute App → App Store Connect → Upload.
10. The target sets `ITSAppUsesNonExemptEncryption` to false, so export compliance should not block you. The app does not use custom encryption.
11. In App Store Connect, open TestFlight and wait for processing. Internal testers on your team can install without beta review. External testers need a short beta review and a group.

The first archive is also when you will want a real 1024×1024 icon review in the asset catalog. One is already in the project.
