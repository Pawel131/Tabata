// Minimal static file server for the web app in ./web.
// Used on hosts that run a Node process (Heroku, Render, Railway, AWS App Runner).
// Static hosts (GitHub Pages, Netlify, Cloudflare Pages, S3) serve ./web directly and don't need this.
const http = require("http");
const fs = require("fs");
const path = require("path");

const ROOT = path.join(__dirname, "web");
const PORT = process.env.PORT || 3000;
const TYPES = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".webmanifest": "application/manifest+json; charset=utf-8",
  ".svg": "image/svg+xml",
  ".png": "image/png",
  ".ico": "image/x-icon",
};

http
  .createServer((req, res) => {
    // Heroku terminates TLS at its router; send plain-HTTP visitors to HTTPS
    // so the service worker and install prompt work.
    if (req.headers["x-forwarded-proto"] === "http") {
      res.writeHead(301, { Location: `https://${req.headers.host}${req.url}` });
      return res.end();
    }

    let pathname;
    try {
      pathname = decodeURIComponent(new URL(req.url, "http://localhost").pathname);
    } catch {
      res.writeHead(400);
      return res.end("Bad request");
    }
    if (pathname.endsWith("/")) pathname += "index.html";
    const file = path.normalize(path.join(ROOT, pathname));
    if (!file.startsWith(ROOT + path.sep)) {
      res.writeHead(403);
      return res.end("Forbidden");
    }

    fs.readFile(file, (err, data) => {
      if (err) {
        res.writeHead(404, { "Content-Type": "text/plain; charset=utf-8" });
        return res.end("Not found");
      }
      const ext = path.extname(file);
      const headers = {
        "Content-Type": TYPES[ext] || "application/octet-stream",
        "X-Content-Type-Options": "nosniff",
        // The service worker and page must revalidate so updates reach installed apps.
        "Cache-Control": ext === ".png" || ext === ".svg" ? "public, max-age=604800" : "no-cache",
      };
      if (path.basename(file) === "sw.js") headers["Service-Worker-Allowed"] = "/";
      res.writeHead(200, headers);
      res.end(data);
    });
  })
  .listen(PORT, () => console.log(`Tabata web app on http://localhost:${PORT}`));
