# Soker App UI

Soker is a sales assistant with two conversation modes. **获客** helps find and deliver leads. **盘客** helps review existing customers and plan follow-up.

The iOS app loads the conversation page in a WKWebView. The chat is a separate H5 frontend made up of React components, styles, interaction logic, and assets. Both frontends are in this repository.

- [iOS](ios/) contains the Xcode project, native shell, and Soker app icon.
- [Web](web/) contains the conversation frontend, including mode switching, message bubbles, customer cards, the sidebar, and the composer.

The public demo uses sample customers and local interactions. Enterprise account authorization, billing, and other service integrations require the enterprise environment.

Start the local preview with `npm ci`, `npm run build`, and `npm start` in `web/`. Open `http://127.0.0.1:3131/chat-tab?mode=acquisition` for the browser preview or run the Soker scheme from `ios/Soker.xcodeproj` on an iOS simulator.

`ios/OriginalUI/` preserves the current native UI source from the app. The standalone Xcode target uses system frameworks. The original screens reference modules from the enterprise app.
