import fs from 'node:fs/promises';
import path from 'node:path';
import { spawn } from 'node:child_process';

// Uses a fresh, task-owned profile. It never connects to the user's browser.
const [url, outputDirectory, executable = 'C:/Program Files/Google/Chrome/Application/chrome.exe'] = process.argv.slice(2);
if (!url || !outputDirectory) {
  throw new Error('Usage: node run-editor-oracle.mjs URL OUTPUT_DIRECTORY [CHROME_EXECUTABLE]');
}
const directory = path.resolve(outputDirectory);
const profile = path.join(directory, `chrome-${Date.now()}`);
await fs.mkdir(profile, { recursive: true });
const browser = spawn(executable, [
  '--headless', '--disable-gpu', '--no-first-run', '--disable-background-networking',
  '--remote-debugging-port=0', `--user-data-dir=${profile}`, '--window-size=1600,1200',
  url,
], { windowsHide: true, stdio: 'ignore' });
const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
let socket;
let pageSocket;
let sequence = 0;
const pending = new Map();
const connect = (endpoint) => new Promise((resolve, reject) => {
  const connection = new WebSocket(endpoint);
  connection.addEventListener('open', () => resolve(connection), { once: true });
  connection.addEventListener('error', reject, { once: true });
  connection.addEventListener('message', (event) => {
    const message = JSON.parse(event.data);
    const request = pending.get(message.id);
    if (!request) return;
    pending.delete(message.id);
    if (message.error) request.reject(new Error(message.error.message));
    else request.resolve(message.result);
  });
});
const call = (connection, method, params = {}) => new Promise((resolve, reject) => {
  const id = ++sequence;
  pending.set(id, { resolve, reject });
  connection.send(JSON.stringify({ id, method, params }));
});
try {
  let port;
  for (let attempt = 0; attempt < 150; attempt++) {
    try {
      port = Number((await fs.readFile(path.join(profile, 'DevToolsActivePort'), 'utf8')).split('\n')[0]);
      break;
    } catch {
      if (browser.exitCode !== null) throw new Error(`Browser exited: ${browser.exitCode}`);
      await wait(100);
    }
  }
  if (!port) throw new Error('Browser did not expose its task-owned DevTools port');
  const metadata = await (await fetch(`http://127.0.0.1:${port}/json/version`)).json();
  socket = await connect(metadata.webSocketDebuggerUrl);
  const pages = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
  const page = pages.find((target) => target.type === 'page' && target.url === url);
  if (!page) throw new Error('Oracle page was not opened');
  pageSocket = await connect(page.webSocketDebuggerUrl);
  await call(pageSocket, 'Page.bringToFront');
  const deadline = Date.now() + 240_000;
  let snapshot;
  while (Date.now() < deadline) {
    const response = await call(pageSocket, 'Runtime.evaluate', {
      expression: '({ title: document.title, result: document.querySelector("#result,#out")?.textContent, html: document.documentElement.outerHTML, hidden: document.hidden, done: window.__ORACLE_DONE__ === true })',
      returnByValue: true,
    });
    snapshot = response.result.value;
    if (/\b(?:PASS|FAIL)\b/.test(snapshot.title) || snapshot.done
      || /^style-baseline \S+$/.test(snapshot.title)) break;
    await wait(200);
  }
  if (!snapshot || (!/\b(?:PASS|FAIL)\b/.test(snapshot.title) && !snapshot.done
    && !/^style-baseline \S+$/.test(snapshot.title))) {
    throw new Error(`Oracle timed out: ${snapshot?.title || 'unknown'}`);
  }
  await fs.writeFile(path.join(directory, 'result.html'), snapshot.html, 'utf8');
  let result;
  try { result = JSON.parse(snapshot.result || 'null'); } catch { result = snapshot.result; }
  await fs.writeFile(path.join(directory, 'result.json'), JSON.stringify({
    title: snapshot.title,
    hidden: snapshot.hidden,
    result,
  }, null, 2), 'utf8');
  const screenshot = await call(pageSocket, 'Page.captureScreenshot', { format: 'png' });
  await fs.writeFile(path.join(directory, 'result.png'), Buffer.from(screenshot.data, 'base64'));
  console.log(`${snapshot.title}; visible=${!snapshot.hidden}; results=${path.join(directory, 'result.json')}`);
  if (/\bFAIL\b/.test(snapshot.title)) process.exitCode = 1;
} finally {
  if (socket?.readyState === WebSocket.OPEN) {
    await call(socket, 'Browser.close').catch(() => {});
  } else if (browser.exitCode === null) {
    browser.kill();
  }
  pageSocket?.close();
  socket?.close();
}
