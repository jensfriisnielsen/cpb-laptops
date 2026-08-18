# Slides

A standalone [reveal.js](https://revealjs.com/) deck on using NixOS to manage laptops for teaching code.

## Reading the deck

Open the deck in a browser:

```sh
firefox slides/index.html
```

Any browser works. If CDN scripts are blocked on `file://`, serve the folder over HTTP instead:

```sh
cd slides
python -m http.server
```

Then open `http://127.0.0.1:8000/`.

### Navigation

Horizontal slides are **sections** (the spectacular benefits). Vertical slides are **detail** for that benefit.

| Key | Action |
| --- | --- |
| Right arrow or Space | Next section |
| Down arrow | More on this topic |
| Left / Up | Back |
| Esc | Overview of all slides |
| F | Fullscreen |
| S | Speaker notes |
| `.` (period) | Pause / blackout |

The table of contents is clickable. Each item jumps to that section.

Hash URLs are shareable, for example `index.html#/identical-classroom` or `index.html#/toc`.

## Deploy

`slides/` is a static site root: `index.html` plus relative `css/`. Copy the whole directory to any web server. No build step, no SPA rewrite rules.

Hash links (`/#/identical-classroom`) work without `try_files` or History API fallbacks.

### rsync

```sh
rsync -a slides/ user@host:/var/www/slides/
```

### nginx

```nginx
server {
  listen 80;
  server_name slides.example.org;
  root /var/www/slides;
  index index.html;
}
```

The same tree also works under a subpath such as `/slides/` because CSS is loaded as `css/theme.css`.

### GitHub Pages (or similar)

Publish the `slides/` folder as the site root.

### CDN vs offline

Reveal.js is loaded from a pinned jsDelivr URL. Presenting from the web needs network access for that CDN.

To present offline or stop depending on jsDelivr later, copy reveal.js `dist/` into `slides/vendor/` and point the `<link>` / `<script>` tags in `index.html` at those files.
