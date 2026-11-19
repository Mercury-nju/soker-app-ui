# Soker iOS demo

The Xcode project contains the public iOS demo shell and the current Soker app icon. It loads the acquisition and customer review interface from the companion web app. Start the web app on port 3131, open Soker.xcodeproj and run the Soker scheme on an iOS simulator. To point it at a deployed HTTPS demo, supply the embedded route as a launch argument after --demo-url.

The shell uses system frameworks and requires no private packages or credentials. The enterprise build uses private shared modules and separately distributed SDKs. Enterprise login, server billing, recording, and native voice input require the enterprise app.
