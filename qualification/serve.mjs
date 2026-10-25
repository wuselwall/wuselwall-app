// Local assets only: no production endpoint, discovery or credentials.
import fs from 'node:fs';
import http from 'node:http';
import path from 'node:path';
import { root } from './matrix.mjs';

const assets = path.join(root, 'app/build/web-qualification');
if (!fs.existsSync(path.join(assets, 'index.html'))) throw new Error('Build qualification/main.dart before starting the server');
const types = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.wasm': 'application/wasm',
  '.json': 'application/json', '.ttf': 'font/ttf', '.png': 'image/png', '.svg': 'image/svg+xml', '.woff2': 'font/woff2' };
const server = http.createServer((req, res) => {
  let file;
  try { file = path.resolve(assets, `.${decodeURIComponent(new URL(req.url, 'http://localhost').pathname)}`); }
  catch { res.writeHead(400).end(); return; }
  if (file !== assets && !file.startsWith(`${assets}${path.sep}`)) { res.writeHead(403).end(); return; }
  if (!fs.existsSync(file) || fs.statSync(file).isDirectory()) file = path.join(assets, 'index.html');
  res.writeHead(200, { 'content-type': types[path.extname(file)] ?? 'application/octet-stream', 'cache-control': 'no-store' });
  fs.createReadStream(file).pipe(res);
});
server.listen(Number(process.env.QUALIFY_WEB_PORT || 4178), '127.0.0.1');
for (const signal of ['SIGINT', 'SIGTERM']) process.on(signal, () => server.close());
