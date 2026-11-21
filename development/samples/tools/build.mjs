// Original offline sample builder. Execute through isolation/Invoke-OfflineProcess.ps1.
import fs from 'node:fs';
import path from 'node:path';
import cp from 'node:child_process';
import crypto from 'node:crypto';
import zlib from 'node:zlib';
import vm from 'node:vm';
const physicalRoot = process.env.DEVTOOLS_PHYSICAL_ROOT;
const driveAlias = process.env.DEVTOOLS_DRIVE_ALIAS;
function mapped(value) {
  if (typeof value === 'string' && physicalRoot && driveAlias) { const prefix = physicalRoot.replace(/[\\/]+$/, ''); if (value.toLowerCase() === prefix.toLowerCase()) return driveAlias; if (value.toLowerCase().startsWith(prefix.toLowerCase() + path.sep)) return driveAlias + value.slice(prefix.length + 1); }
  if (Array.isArray(value)) return value.map(mapped);
  if (value && typeof value === 'object') return Object.fromEntries(Object.entries(value).map(([k,v]) => [k,mapped(v)]));
  return value;
}
function physical(value) { return typeof value === 'string' && physicalRoot && driveAlias && value.toLowerCase().startsWith(driveAlias.toLowerCase()) ? physicalRoot + path.sep + value.slice(driveAlias.length) : value; }
const config = mapped(JSON.parse(fs.readFileSync(process.argv[2], 'utf8')));
if (config.targets.includes('portableapps') && !config.targets.includes('windows')) config.targets.unshift('windows');
const root = path.resolve(config.ownedRoot);
const rootPrefix = root.endsWith(path.sep) ? root : root + path.sep;
const source = path.resolve(config.sources);
const output = path.resolve(config.output);
for (const value of [source, output, ...Object.values(config.tools)]) {
  if (!path.resolve(value).toLowerCase().startsWith(rootPrefix.toLowerCase())) throw Error('Build path escapes owned root');
}
fs.mkdirSync(output, {recursive: true});
const log = path.join(output, 'logs'); fs.mkdirSync(log, {recursive: true});
const commands = []; const artifacts = []; const results = [];
function run(name, executable, args, cwd = output) {
  const started = new Date().toISOString();
  const outFile = path.join(log, name + '.stdout.txt'), errFile = path.join(log, name + '.stderr.txt');
  let outHandle, errHandle, result;
  try { outHandle = fs.openSync(outFile, 'wx'); errHandle = fs.openSync(errFile, 'wx'); result = cp.spawnSync(executable, args, {cwd, stdio: ['ignore', outHandle, errHandle], windowsHide: true, timeout: 180000, env: process.env}); } finally { try { if (outHandle !== undefined) fs.closeSync(outHandle); } finally { if (errHandle !== undefined) fs.closeSync(errHandle); } }
  if (fs.statSync(outFile).size > 16 * 1024 * 1024 || fs.statSync(errFile).size > 16 * 1024 * 1024) throw Error(name + ' exceeded log read budget');
  result.stdout = fs.readFileSync(outFile, 'utf8'); result.stderr = fs.readFileSync(errFile, 'utf8');
  commands.push({name, executable: physical(executable), argumentCount: args.length, cwd: physical(cwd), started, exitCode: result.status, error: result.error?.message || null});
  fs.writeFileSync(path.join(output, 'commands.json'), JSON.stringify(commands, null, 2));
  console.log(name + ': ' + result.status);
  if (/SCRIPT ERROR|Parse Error|Failed to load script/.test(result.stderr + result.stdout)) throw Error(name + ' logged a script compilation failure');
  if (result.status !== 0) throw Error(name + ' failed: ' + (result.error?.message || result.stderr || result.stdout));
  return result.stdout;
}
function artifact(target, name, kind) {
  const bytes = fs.readFileSync(name);
  artifacts.push({target, path: physical(name), kind, sizeBytes: bytes.length, sha256: crypto.createHash('sha256').update(bytes).digest('hex')});
}
function put(name, bytes) { fs.mkdirSync(path.dirname(name), {recursive: true}); fs.writeFileSync(name, bytes); }
function crc32(data) {
  let value = 0xffffffff;
  for (const byte of data) { value ^= byte; for (let bit = 0; bit < 8; ++bit) value = (value >>> 1) ^ ((value & 1) ? 0xedb88320 : 0); }
  return (value ^ 0xffffffff) >>> 0;
}
function zip(filename, entries) {
  const blocks = [], directory = []; let offset = 0;
  for (const [name, input] of entries) {
    if (!/^[a-zA-Z0-9_.\/-]+$/.test(name) || name.startsWith('/') || name.split('/').some(p => p === '..' || p === '')) throw Error('Unsafe ZIP path');
    const data = Buffer.isBuffer(input) ? input : Buffer.from(input);
    const encoded = Buffer.from(name); const crc = crc32(data);
    const header = Buffer.alloc(30); header.writeUInt32LE(0x04034b50); header.writeUInt16LE(20,4); header.writeUInt16LE(0x800,6); header.writeUInt16LE(33,12); header.writeUInt32LE(crc,14); header.writeUInt32LE(data.length,18); header.writeUInt32LE(data.length,22); header.writeUInt16LE(encoded.length,26);
    blocks.push(header, encoded, data);
    const central = Buffer.alloc(46); central.writeUInt32LE(0x02014b50); central.writeUInt16LE(20,4); central.writeUInt16LE(20,6); central.writeUInt16LE(0x800,8); central.writeUInt16LE(33,14); central.writeUInt32LE(crc,16); central.writeUInt32LE(data.length,20); central.writeUInt32LE(data.length,24); central.writeUInt16LE(encoded.length,28); central.writeUInt32LE(offset,42); directory.push(central,encoded); offset += header.length + encoded.length + data.length;
  }
  const size = directory.reduce((sum, b) => sum + b.length, 0); const end = Buffer.alloc(22); end.writeUInt32LE(0x06054b50); end.writeUInt16LE(entries.length,8); end.writeUInt16LE(entries.length,10); end.writeUInt32LE(size,12); end.writeUInt32LE(offset,16); put(filename,Buffer.concat([...blocks,...directory,end]));
}
function png(size) {
  const pixels=Buffer.alloc((size*4+1)*size);
  for(let y=0;y<size;y++)for(let x=0;x<size;x++){const p=y*(size*4+1)+1+x*4;pixels[p]=39;pixels[p+1]=88;pixels[p+2]=172;pixels[p+3]=255;if(x>size*.3&&x<size*.7&&y>size*.25&&y<size*.75){pixels[p]=80;pixels[p+1]=217;pixels[p+2]=176;}}
  const chunk=(kind,data)=>{const type=Buffer.from(kind), b=Buffer.alloc(12+data.length);b.writeUInt32BE(data.length);type.copy(b,4);data.copy(b,8);b.writeUInt32BE(crc32(Buffer.concat([type,data])),8+data.length);return b;};
  const header=Buffer.alloc(13);header.writeUInt32BE(size);header.writeUInt32BE(size,4);header[8]=8;header[9]=6;
  return Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]),chunk('IHDR',header),chunk('IDAT',zlib.deflateSync(pixels)),chunk('IEND',Buffer.alloc(0))]);
}
function icon() {
  const size=32, dib=Buffer.alloc(40+size*size*4+size*4);dib.writeUInt32LE(40);dib.writeInt32LE(size,4);dib.writeInt32LE(size*2,8);dib.writeUInt16LE(1,12);dib.writeUInt16LE(32,14);dib.writeUInt32LE(size*size*4,20);
  for(let y=0;y<size;y++)for(let x=0;x<size;x++){const p=40+(y*size+x)*4;dib[p]=172;dib[p+1]=88;dib[p+2]=39;dib[p+3]=255;if(x>9&&x<23&&y>7&&y<25){dib[p]=176;dib[p+1]=217;dib[p+2]=80;}}
  const head=Buffer.alloc(22);head.writeUInt16LE(1,2);head.writeUInt16LE(1,4);head[6]=size;head[7]=size;head.writeUInt16LE(1,10);head.writeUInt16LE(32,12);head.writeUInt32LE(dib.length,14);head.writeUInt32LE(22,18);return Buffer.concat([head,dib]);
}
function windows() {
  const dir=path.join(output,'windows');fs.mkdirSync(dir,{recursive:true});
  put(path.join(dir,'app.ico'),icon());for(const size of [16,32,128])put(path.join(dir,`appicon_${size}.png`),png(size));
  put(path.join(dir,'app.manifest'),'<?xml version="1.0" encoding="UTF-8" standalone="yes"?><assembly xmlns="urn:schemas-microsoft-com:asm.v1" manifestVersion="1.0"><trustInfo xmlns="urn:schemas-microsoft-com:asm.v3"><security><requestedPrivileges><requestedExecutionLevel level="asInvoker" uiAccess="false"/></requestedPrivileges></security></trustInfo></assembly>');
  put(path.join(dir,'app.rc'),'1 ICON "app.ico"\n1 24 "app.manifest"\n');
  run('windows-resources',config.tools.zig,['rc','--','app.rc','app.res'],dir);
  const exe=path.join(dir,'OfflineSample.exe');
  run('windows-compile',config.tools.zig,['build-exe',path.join(source,'windows/app.c'),'app.res','-target','x86_64-windows-gnu','-I',path.join(path.dirname(config.tools.zig),'lib/libc/include/any-windows-any'),'-luser32','-lgdi32','-lkernel32','-O','ReleaseSmall','-fstrip','-fentry=WinMainCRTStartup','--subsystem','windows','-femit-bin='+exe],dir);
  artifact('windows',exe,'native Windows x64 PE executable');results.push({target:'windows',status:'Built',runtime:'NotRun'});
}
function web() {
  const dir=path.join(output,'website');fs.mkdirSync(dir,{recursive:true}); const entries=[];
  for(const name of ['index.html','style.css','app.js']){const data=fs.readFileSync(path.join(source,'website',name));put(path.join(dir,name),data);entries.push([name,data]);}
  new vm.Script(entries[2][1].toString());
  const listener={};const label={textContent:''};const button={addEventListener:(kind,handler)=>{listener[kind]=handler;}};
  vm.runInNewContext(entries[2][1].toString(),{document:{getElementById:id=>id==='increment'?button:label}});listener.click();if(label.textContent!=='Count: 1')throw Error('Website button fixture failed');
  const out=path.join(output,'website.zip');zip(out,entries);artifact('website',out,'static website ZIP');results.push({target:'website',status:'PackagedAndValidated',validation:'Node syntax and DOM fixture; real browser not run'});
}
function userscript() {
  const data=fs.readFileSync(path.join(source,'userscript/offline-label.user.js'));const text=data.toString();
  if(!text.includes('@match        https://example.com/*')||!text.includes('@grant        none'))throw Error('Userscript scope mismatch');
  const list=[];const document={getElementById:id=>list.find(x=>x.id===id),createElement:()=>({}),body:{appendChild:item=>list.push(item)}};
  const script=new vm.Script(text);script.runInNewContext({document});script.runInNewContext({document});if(list.length!==1||list[0].textContent!=='Offline Sample')throw Error('Userscript idempotence failed');
  const out=path.join(output,'offline-label.user.js');put(out,data);artifact('userscript',out,'userscript text');results.push({target:'userscript',status:'PackagedAndValidated',validation:'Node syntax/DOM fixture; manager not run'});
}
function userstyle() {
  const data=fs.readFileSync(path.join(source,'userstyle/offline-example.user.css'));const text=data.toString();
  const stripped=text.replace(/\/\*[\s\S]*?\*\//g,'').replace(/"(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*'/g,'""');let depth=0;
  for(const c of stripped){if(c==='{')depth++;else if(c==='}'&&--depth<0)throw Error('Unbalanced CSS');}if(depth!==0||!text.includes('@-moz-document domain("example.com")')||/@import|url\s*\(/i.test(stripped))throw Error('CSS scope/resource mismatch');
  const out=path.join(output,'offline-example.user.css');put(out,data);artifact('userstyle',out,'UserCSS text');results.push({target:'userstyle',status:'PackagedAndValidated',validation:'Narrow scope/resource and balanced CSS checks; manager/rendering not run'});
}
function dependency() {
  const dir=path.join(output,'dependency');fs.mkdirSync(dir,{recursive:true});const lib=path.join(dir,'library-classes'),consumer=path.join(dir,'consumer-classes');fs.mkdirSync(lib);fs.mkdirSync(consumer);
  run('dependency-compile',config.tools.javac,['-source','8','-target','8','-d',lib,path.join(source,'dependency/library/org/devtools/math/Squares.java')]);
  const jar=path.join(dir,'offline-math.jar');zip(jar,[['META-INF/MANIFEST.MF','Manifest-Version: 1.0\r\n\r\n'],['META-INF/LICENSE',fs.readFileSync(path.join(source,'LICENSE'))],['org/devtools/math/Squares.class',fs.readFileSync(path.join(lib,'org/devtools/math/Squares.class'))]]);
  run('dependency-consumer-compile',config.tools.javac,['-source','8','-target','8','-classpath',jar,'-d',consumer,path.join(source,'dependency/consumer/Consume.java')]);
  run('dependency-consumer-run',config.tools.java,['-classpath',consumer+path.delimiter+jar,'Consume'],consumer);
  artifact('dependency',jar,'Java JAR');results.push({target:'dependency',status:'BuiltAndConsumed',validation:'Separate consumer compiled/run against packed JAR, not library source'});
}

function filesIn(dir) {
  const result=[];
  for(const item of fs.readdirSync(dir,{withFileTypes:true})){const p=path.join(dir,item.name);if(item.isSymbolicLink())throw Error('Links not allowed in project outputs');if(item.isDirectory())result.push(...filesIn(p));else if(item.isFile())result.push(p);}
  return result;
}
function unzip(filename) {
  const b=fs.readFileSync(filename);if(b.length>256*1024*1024)throw Error('ZIP input limit');let end=-1;
  for(let i=b.length-22;i>=Math.max(0,b.length-65557);--i)if(b.readUInt32LE(i)===0x06054b50){end=i;break;}
  if(end<0||b.readUInt16LE(end+4)||b.readUInt16LE(end+6))throw Error('Invalid/multidisk ZIP');
  const count=b.readUInt16LE(end+10);if(count>10000)throw Error('ZIP count limit');let offset=b.readUInt32LE(end+16),total=0;const result=[];const seen=new Set();
  for(let i=0;i<count;++i){if(b.readUInt32LE(offset)!==0x02014b50)throw Error('Invalid ZIP directory');const flags=b.readUInt16LE(offset+8),method=b.readUInt16LE(offset+10),crc=b.readUInt32LE(offset+16),compressed=b.readUInt32LE(offset+20),size=b.readUInt32LE(offset+24),n=b.readUInt16LE(offset+28),extra=b.readUInt16LE(offset+30),comment=b.readUInt16LE(offset+32),local=b.readUInt32LE(offset+42);const name=b.subarray(offset+46,offset+46+n).toString('utf8');offset+=46+n+extra+comment;if(name.endsWith('/'))continue;if(flags&1||size>128*1024*1024||(total+=size)>512*1024*1024)throw Error('ZIP expansion/encryption limit');if(name.startsWith('/')||name.includes('\\')||name.split('/').some(p=>p==='..'||p==='')||seen.has(name.toLowerCase()))throw Error('Unsafe/duplicate ZIP name');seen.add(name.toLowerCase());if(b.readUInt32LE(local)!==0x04034b50)throw Error('Invalid ZIP local header');const start=local+30+b.readUInt16LE(local+26)+b.readUInt16LE(local+28);const data=b.subarray(start,start+compressed);const plain=method===0?Buffer.from(data):method===8?zlib.inflateRawSync(data,{maxOutputLength:128*1024*1024}):null;if(!plain||plain.length!==size||crc32(plain)!==crc)throw Error('ZIP identity mismatch');result.push([name,plain]);}
  return result;
}
function signingKey() {
  const file=path.join(output,'test-debug.keystore');
  if(!fs.existsSync(file))run('debug-key',config.tools.keytool,['-genkeypair','-keystore',file,'-storepass','android','-keypass','android','-alias','androiddebugkey','-dname','CN=DevTools Offline Test Fixture','-keyalg','RSA','-keysize','2048','-validity','3650','-noprompt']);
  return file;
}
function androidApp() {
  const dir=path.join(output,'android-app');fs.mkdirSync(dir,{recursive:true});const classes=path.join(dir,'classes'),generated=path.join(dir,'generated'),dex=path.join(dir,'dex');for(const p of [classes,generated,dex])fs.mkdirSync(p);
  const base=path.join(dir,'resources.apk');run('android-resources',config.tools.aapt2,['link','-o',base,'-I',config.tools.androidJar,'--manifest',path.join(source,'android-app/AndroidManifest.xml'),'--java',generated]);
  run('android-java',config.tools.javac,['-source','8','-target','8','-bootclasspath',config.tools.androidJar,'-d',classes,path.join(source,'android-app/src/org/devtools/offlineapp/MainActivity.java')]);
  run('android-dex',config.tools.java,['-Djava.io.tmpdir='+process.env.TEMP,'-cp',config.tools.d8Jar,'com.android.tools.r8.D8','--lib',config.tools.androidJar,'--min-api','23','--output',dex,...filesIn(classes).filter(p=>p.endsWith('.class'))]);
  const entries=unzip(base);entries.push(['classes.dex',fs.readFileSync(path.join(dex,'classes.dex'))]);const assembled=path.join(dir,'assembled.apk');zip(assembled,entries);
  const aligned=path.join(dir,'aligned.apk');run('android-align',config.tools.zipalign,['-f','4',assembled,aligned]);
  const apk=path.join(dir,'OfflineApp.apk');run('android-sign',config.tools.java,['-Djava.io.tmpdir='+process.env.TEMP,'-jar',config.tools.apksignerJar,'sign','--ks',signingKey(),'--ks-key-alias','androiddebugkey','--ks-pass','pass:android','--key-pass','pass:android','--out',apk,aligned]);
  run('android-signature',config.tools.java,['-jar',config.tools.apksignerJar,'verify','--verbose',apk]);
  const badging=run('android-manifest',config.tools.aapt2,['dump','badging',apk]);if(!badging.includes("package: name='org.devtools.offlineapp'")||!badging.includes('launchable-activity'))throw Error('Android manifest identity mismatch');
  const actual=unzip(apk);const bytecode=actual.find(x=>x[0]==='classes.dex');if(!bytecode||!bytecode[1].subarray(0,4).equals(Buffer.from('dex\n')))throw Error('Missing actual DEX');
  artifact('android-app',apk,'signed Android APK');results.push({target:'android-app',status:'BuiltAndVerified',validation:'Actual Java/DEX/resource/link/alignment/debug signature/manifest checks',runtime:'NotRun',prerequisite:'Explicit private licensed Android SDK; not redistributed'});
}
function godotExports() {
  const project=path.join(output,'godot-project');fs.cpSync(path.join(source,'godot-game'),project,{recursive:true});
  const val=p=>JSON.stringify(p.replaceAll('\\','/'));
  const presets=`[preset.0]\nname="Windows Desktop"\nplatform="Windows Desktop"\nrunnable=false\nexport_filter="all_resources"\ninclude_filter="*.txt"\nexclude_filter=""\nexport_path=""\n[preset.0.options]\ncustom_template/debug=${val(config.tools.godotWindowsDebug)}\ncustom_template/release=${val(config.tools.godotWindowsRelease)}\nbinary_format/architecture="x86_64"\nbinary_format/embed_pck=false\ncodesign/enable=false\n[preset.1]\nname="Android"\nplatform="Android"\nrunnable=false\nexport_filter="all_resources"\ninclude_filter="*.txt"\nexclude_filter=""\nexport_path=""\n[preset.1.options]\ncustom_template/debug=${val(config.tools.godotAndroidDebug)}\ncustom_template/release=${val(config.tools.godotAndroidRelease)}\ngradle_build/use_gradle_build=false\narchitectures/armeabi-v7a=false\narchitectures/arm64-v8a=true\narchitectures/x86=false\narchitectures/x86_64=false\npackage/unique_name="org.devtools.offlinegame"\npackage/name="Offline Circle"\npackage/signed=false\npermissions/internet=false\n`;
  put(path.join(project,'export_presets.cfg'),presets);
  const key=signingKey();
  const settings='[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'+
    'export/android/java_sdk_path = '+val(path.dirname(path.dirname(config.tools.java)))+'\n'+
    'export/android/android_sdk_path = '+val(config.tools.androidSdk)+'\n'+
    'export/android/debug_keystore = '+val(key)+'\n'+
    'export/android/debug_keystore_user = "androiddebugkey"\nexport/android/debug_keystore_pass = "android"\nexport/android/shutdown_adb_on_exit = false\n';
  put(path.join(process.env.APPDATA,'Godot/editor_settings-4.7.tres'),settings);
  for(const [name,input] of [['LICENSE.txt',path.join(source,'LICENSE')],['Godot_LICENSE.txt',config.tools.godotLicense],['Godot_COPYRIGHT.txt',config.tools.godotCopyright]]) fs.copyFileSync(input,path.join(project,name));
  run('godot-script-parse',config.tools.godot,['--headless','--path',project,'--check-only','--script','res://main.gd']);
  run('godot-import',config.tools.godot,['--headless','--editor','--path',project,'--import']);
  const pc=path.join(output,'pc-game');fs.mkdirSync(pc);const executable=path.join(pc,'OfflineCircle.exe');
  run('pc-game-export',config.tools.godot,['--headless','--path',project,'--export-release','Windows Desktop',executable]);
  for(const name of ['LICENSE.txt','Godot_LICENSE.txt','Godot_COPYRIGHT.txt']) fs.copyFileSync(path.join(project,name),path.join(pc,name));
  artifact('pc-game',executable,'Godot Windows x64 game executable');artifact('pc-game',path.join(pc,'OfflineCircle.pck'),'Godot project content pack');results.push({target:'pc-game',status:'Built',runtime:'NotRun'});
  const unsigned=path.join(output,'OfflineCircle-unsigned.apk');run('android-game-export',config.tools.godot,['--headless','--path',project,'--export-debug','Android',unsigned]);
  const apk=path.join(output,'OfflineCircle.apk');run('android-game-sign',config.tools.java,['-jar',config.tools.apksignerJar,'sign','--ks',key,'--ks-key-alias','androiddebugkey','--ks-pass','pass:android','--key-pass','pass:android','--out',apk,unsigned]);
  run('android-game-signature',config.tools.java,['-jar',config.tools.apksignerJar,'verify','--verbose',apk]);const badging=run('android-game-manifest',config.tools.aapt2,['dump','badging',apk]);if(!badging.includes("package: name='org.devtools.offlinegame'"))throw Error('Android game identity mismatch');artifact('android-game',apk,'Godot signed Android APK');results.push({target:'android-game',status:'BuiltAndVerified',runtime:'NotRun',deviceOperations:'No runnable Android preset; export only',prerequisite:'Explicit private licensed Android SDK; not redistributed'});
}
function wow() {
  run('wow-lua-syntax',config.tools.luac,['-p',path.join(source,'wow-addon/OfflineSample.lua')]);const entries=['OfflineSample.toc','OfflineSample.lua'].map(name=>['OfflineSample/'+name,fs.readFileSync(path.join(source,'wow-addon',name))]);if(!entries[0][1].toString().includes('## Interface: 16001'))throw Error('TOC fixture version mismatch');const archive=path.join(output,'OfflineSample-addon.zip');zip(archive,entries);artifact('wow-addon',archive,'WoW addon ZIP');results.push({target:'wow-addon',status:'PackagedAndSyntaxChecked',clientInterface:16001,runtime:'NotRun'});
}


function portableapps() {
  const dir=path.join(output,'portableapps');fs.mkdirSync(dir,{recursive:true});const pkg=path.join(dir,'OfflineSamplePortable');fs.cpSync(path.join(source,'portableapps/OfflineSamplePortable'),pkg,{recursive:true});
  const app=path.join(pkg,'App/OfflineSample');fs.mkdirSync(app,{recursive:true});fs.copyFileSync(path.join(output,'windows/OfflineSample.exe'),path.join(app,'OfflineSample.exe'));fs.copyFileSync(path.join(source,'LICENSE'),path.join(app,'LICENSE'));fs.copyFileSync(path.join(source,'windows/app.c'),path.join(pkg,'Other/Source/BaseApp.c'));
  const info=path.join(pkg,'App/AppInfo');for(const name of ['app.ico','appicon_16.png','appicon_32.png','appicon_128.png'])fs.copyFileSync(path.join(output,'windows',name),path.join(info,name==='app.ico'?'appicon.ico':name));
  const work=path.join(dir,'build-tools');fs.mkdirSync(work);const pal=path.join(work,'PortableApps.comLauncher'),installer=path.join(work,'PortableApps.comInstaller');fs.cpSync(config.tools.palRoot,pal,{recursive:true});fs.cpSync(config.tools.installerRoot,installer,{recursive:true});
  run('portableapps-launcher-source-compile',path.join(pal,'App/NSIS/makensis.exe'),['/DPACKAGE='+pkg,'/DNamePortable=Offline Native Sample Portable','/DAppID=OfflineSamplePortable','/DVersion=1.0.0.0',path.join(pal,'Other/Source/PortableApps.comLauncher.nsi')],path.join(pal,'Other/Source'));
  artifact('portableapps',path.join(pkg,'OfflineSamplePortable.exe'),'PortableApps.com Launcher executable');
  // Fixed-fixture source backend: each definition follows InstallerWizard.nsi 3.9.24.
  // The official GUI and bundled legacy compiler fail native lowbox startup (623).
  const installerSource=path.join(pkg,'Other/Source');
  fs.cpSync(path.join(installer,'App/installer'),installerSource,{recursive:true});
  for(const name of ['PortableApps.comInstallerHeader.bmp','PortableApps.comInstallerHeaderRTL.bmp'])fs.copyFileSync(path.join(installer,'App/default_bits',name),path.join(installerSource,name));
  const definitions={PORTABLEAPPNAME:'Offline Native Sample Portable',PORTABLEAPPNAMEDOUBLEDAMPERSANDS:'Offline Native Sample Portable',APPID:'OfflineSamplePortable',VERSION:'1.0.0.0',FILENAME:'OfflineSamplePortable_1.0_English',REQUIRESADMIN:'no',FINISHPAGERUN:'OfflineSamplePortable.exe',CHECKRUNNING:'OfflineSamplePortable.exe',CLOSENAME:'Offline Native Sample Portable',ADDONSDIRECTORYPRESERVE:'NONE',INSTALLERCOMMENTS:'For additional details, visit PortableApps.com',INSTALLERADDITIONALTRADEMARKS:'',INCLUDEINSTALLERSOURCE:'true',INSTALLERLANGUAGE:'English',REMOVEAPPDIRECTORY:'true',REMOVEOTHERDIRECTORY:'true'};
  const configFile=path.join(installerSource,'PortableApps.comInstallerConfig.nsh');let original=fs.readFileSync(configFile);let header=original[0]===255&&original[1]===254?original.subarray(2).toString('utf16le'):original.toString('utf8').replace(/^\uFEFF/,'');
  header+='\r\n;Fixed original fixture configuration derived from official InstallerWizard 3.9.24; GUI not claimed tested.\r\n';for(const [key,value]of Object.entries(definitions))header+='!define '+key+' "'+value+'"\r\n';put(configFile,Buffer.from('\uFEFF'+header,'utf16le'));
  // Supported package-local icon source route; installed tools remain unchanged.
  fs.copyFileSync(path.join(info,'appicon.ico'),path.join(installerSource,'PortableApps.comInstaller.ico'));
  const previousNsisDir=process.env.NSISDIR; process.env.NSISDIR=path.join(installer,'App/nsis');
  try { run('portableapps-installer-source-compile',config.tools.nsisCompiler,[path.join(installerSource,'PortableApps.comInstaller.nsi')],installerSource); } finally { if(previousNsisDir===undefined) delete process.env.NSISDIR; else process.env.NSISDIR=previousNsisDir; }
  const files=fs.readdirSync(dir).filter(name=>name.endsWith('.paf.exe'));if(files.length!==1)throw Error('Expected one PAF installer');artifact('portableapps',path.join(dir,files[0]),'PortableApps.com PAF installer');results.push({target:'portableapps',status:'Built',installation:'NotRun',runtimePortability:'NotRun',sourceBackend:'Official PAL and Installer source; fixed fixture configuration derived from current Wizard',generatorUI:'Blocked by native Win32 error 623; not claimed passed'});
}

const targets={windows,website:web,userscript,userstyle,dependency,"android-app":androidApp,"godot-games":godotExports,"wow-addon":wow,portableapps};
try {
  for(const target of config.targets) {if(!targets[target])throw Error('Unknown target '+target);targets[target]();}
  put(path.join(output,'build-results.json'),JSON.stringify({status:'Passed',results,artifacts,commands,offline:'AppContainer wrapper evidence required; this builder alone is not a network sandbox'},null,2));
} catch(error) {put(path.join(output,'build-results.json'),JSON.stringify({status:'Failed',error:String(error),results,artifacts,commands},null,2));console.error(error);process.exitCode=1;}
