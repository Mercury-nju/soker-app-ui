# Soker conversation frontend

Run `npm ci` and `npm run dev` from this folder. The local browser demo is available at [127.0.0.1:3131](http://127.0.0.1:3131/). Set `PORT` to use a different port.

The iOS shell opens `/chat-tab?mode=acquisition&embedded=1` and supplies its native composer over the WebKit bridge. In a browser, the same route shows the web composer. Add `preview=0` to begin an empty conversation.

`npm run build` generates the static site in `dist/`. Configure the static host to serve `index.html` at both `/` and `/chat-tab`. The demo uses sample leads and local state.
