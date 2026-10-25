"""Run after `flutter build web --release --no-web-resources-cdn`.

Cloudflare / LiteSpeed served flutter_bootstrap.js and main.dart.js with a one-year
cache, so phones kept the old app after an upload (2026-10-25: new files on the
server, Cloudflare still handing out the Sep 01 bootstrap). Every build therefore
gets new URLs: flutter_bootstrap.js?v=<hash> (index.html), main.dart.js?v=<hash>
(build config) and the CanvasKit folder renamed to canvaskit-<engine>/ (engine
files must match main.dart.js). index.html itself is not cached by Cloudflare.
"""
import hashlib, json, os, re, shutil, sys

W = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'build', 'web')
main = open(os.path.join(W, 'main.dart.js'), 'rb').read()
v = hashlib.md5(main).hexdigest()[:10]

bp = os.path.join(W, 'flutter_bootstrap.js')
b = open(bp, encoding='utf-8').read()
assert '"mainJsPath":"main.dart.js"' in b, 'build config changed: check flutter_bootstrap.js'
b = b.replace('"mainJsPath":"main.dart.js"', '"mainJsPath":"main.dart.js?v=%s"' % v)
rev = re.search(r'"engineRevision":"([a-f0-9]+)"', b).group(1)[:10]
ck = 'canvaskit-' + rev
if os.path.isdir(os.path.join(W, 'canvaskit')):
    shutil.rmtree(os.path.join(W, ck), ignore_errors=True)
    os.rename(os.path.join(W, 'canvaskit'), os.path.join(W, ck))
a = '_flutter.loader.load({\n'
assert a in b
b = b.replace(a, a + '  config: { canvasKitBaseUrl: "%s/" },\n' % ck, 1)
open(bp, 'w', encoding='utf-8').write(b)

ip = os.path.join(W, 'index.html')
h = open(ip, encoding='utf-8').read()
h2 = re.sub(r'src="flutter_bootstrap\.js(\?v=[a-f0-9]+)?"', 'src="flutter_bootstrap.js?v=%s"' % v, h)
assert h2 != h or ('?v=' + v) in h
open(ip, 'w', encoding='utf-8').write(h2)
print('stamped', v, ck)
