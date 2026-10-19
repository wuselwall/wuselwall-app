import https from 'node:https';
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import os from 'node:os';
import { execFileSync } from 'node:child_process';
import { chromium } from 'playwright';
// Real-browser regression for installer setup links (cold load, reload, and a link opened
// in an already running tab). Needs a web build without a fixed server:
//   (cd app && flutter build web --release --dart-define=ENV=ci -o build/web-setup-probe)
//   node scripts/setup-link-browser.smoke.mjs
// Discovery and Auth are answered by a synthetic fixture; nothing leaves the machine.
const here=fs.mkdtempSync(path.join(os.tmpdir(),'ww-setup-link-'));
execFileSync('openssl',['req','-x509','-newkey','rsa:2048','-nodes','-keyout',here+'/key.pem','-out',here+'/cert.pem','-days','1','-subj','/CN=localhost'],{stdio:'ignore'});
const root=path.resolve(process.argv[2]??'app/build/web-setup-probe');
const types={'.html':'text/html','.js':'text/javascript','.json':'application/json','.wasm':'application/wasm','.ttf':'font/ttf'};
const server=https.createServer({key:fs.readFileSync(here+'/key.pem'),cert:fs.readFileSync(here+'/cert.pem')},(req,res)=>{
 let f=path.join(root,new URL(req.url,'https://localhost').pathname);
 if(!f.startsWith(root)||!fs.existsSync(f)||fs.statSync(f).isDirectory())f=root+'/index.html';
 res.writeHead(200,{'content-type':types[path.extname(f)]||'application/octet-stream'});fs.createReadStream(f).pipe(res);
});
await new Promise(r=>server.listen(0,'127.0.0.1',r));
const base=`https://localhost:${server.address().port}`;
const browser=await chromium.launch({headless:true});
try{
 const context=await browser.newContext({ignoreHTTPSErrors:true,locale:'en-GB',viewport:{width:390,height:844}});
 const page=await context.newPage();
 const errors=[];page.on('pageerror',e=>errors.push(e.message));
 await page.route('https://api.example.org/**',async route=>{
  const url=route.request().url();
  if(url.includes('wuselwall.json')||url.includes('server-info'))return route.fulfill({json:{wuselwall:1,supabase_url:'https://api.example.org',publishable_key:'sb_publishable_browser_probe_only',api_version:1,min_app_version:'0.0.0',household_creation:'code',features:[]}});
  if(url.includes('/auth/v1/otp'))return route.fulfill({json:{}});
  return route.fulfill({status:401,json:{message:'Browser probe has no authenticated session'}});
 });
 const token='0123456789abcdef01234567';
 await page.goto(base+'/#setup='+token+'&server=https://api.example.org');
 async function semantics(){
  await page.waitForSelector('flt-glass-pane',{state:'attached',timeout:90000});
  await page.locator('flt-semantics-placeholder').evaluate(e=>e.click()).catch(()=>{});
  await page.waitForSelector('flt-semantics',{state:'attached',timeout:30000});
 }
 await semantics();
 await page.getByRole('textbox').first().waitFor({timeout:30000});
 console.log('Initial text:',(await page.locator('body').innerText()).slice(-1800));
 assert.ok(!page.url().includes(token),'capability remains in browser URL');
 assert.match(await page.locator('body').innerText(),/I have a password/,'expected direct email entry');
 await page.reload();await semantics();
 await page.getByRole('textbox').first().waitFor({timeout:30000});
 assert.match(await page.locator('body').innerText(),/I have a password/,'expected retained setup to resume email entry after reload');
 assert.ok(!page.url().includes(token));
 console.log('PASS: real Chromium/HTTPS setup capture, fragment removal, secure-storage reload and direct email entry (discovery/API mocked).');
 console.log('Browser errors:',JSON.stringify(errors));
 await context.close();
 // Warm path: the app is already open on the front door, then the setup link is opened
 // in the same tab (only the fragment changes, no document load).
 const warm=await browser.newContext({ignoreHTTPSErrors:true,locale:'en-GB',viewport:{width:390,height:844}});
 const w=await warm.newPage();
 await w.route('https://api.example.org/**',async route=>{
  const url=route.request().url();
  if(url.includes('wuselwall.json')||url.includes('server-info'))return route.fulfill({json:{wuselwall:1,supabase_url:'https://api.example.org',publishable_key:'sb_publishable_browser_probe_only',api_version:1,min_app_version:'0.0.0',household_creation:'code',features:[]}});
  return route.fulfill({status:401,json:{message:'probe'}});
 });
 await w.goto(base+'/');
 await w.waitForSelector('flt-glass-pane',{state:'attached',timeout:90000});
 await w.waitForTimeout(3000);
 await w.evaluate(t=>{location.hash='setup='+t+'&server=https://api.example.org';},token);
 await w.waitForTimeout(1500);
 await w.waitForSelector('flt-glass-pane',{state:'attached',timeout:90000});
 await w.locator('flt-semantics-placeholder').evaluate(e=>e.click()).catch(()=>{});
 await w.getByRole('textbox').first().waitFor({timeout:30000});
 assert.ok(!w.url().includes(token),'warm: capability remains in browser URL');
 assert.match(await w.locator('body').innerText(),/I have a password/,'warm: expected direct email entry');
 const stored=await w.evaluate(()=>Object.keys(localStorage).filter(k=>k.includes('pending-setup')).length);
 assert.equal(stored,1,'warm: setup capability not stored');
 console.log('PASS: warm same-document setup link captured, scrubbed, email entry shown.');
 await warm.close();
}finally{await browser.close();server.close();fs.rmSync(here,{recursive:true,force:true});}
