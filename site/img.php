<?php
/**
 * Paramall image proxy.
 *
 * Flutter Web draws images on a canvas, which requires the image host to allow
 * cross-origin use (CORS). Alfamart's image CDN (c.alfagift.id) sends no CORS
 * headers, so product photos can't render in the Flutter app directly.
 * This script fetches the image server-side and re-serves it from OUR domain
 * (same-origin), which makes CORS a non-issue.
 *
 * Usage:  /img.php?u=<url-encoded image URL>
 * Only hosts in $ALLOWED are fetched; anything else gets 403.
 */

$ALLOWED = ['wcamobile.b-cdn.net', 'paramall.h2olaundry.com', 'c.alfagift.id', 'cdn.klikindomaret.com', 'ap-mc.klikindomaret.com'];

$u = isset($_GET['u']) ? $_GET['u'] : '';
if ($u === '') { http_response_code(400); exit('missing u'); }

$parts = parse_url($u);
if (!$parts || !isset($parts['host']) || !isset($parts['scheme'])) { http_response_code(400); exit('bad url'); }
if ($parts['scheme'] !== 'https') { http_response_code(400); exit('https only'); }
if (!in_array(strtolower($parts['host']), $ALLOWED, true)) { http_response_code(403); exit('host not allowed'); }

// Local file cache (7 days) so repeat views don't re-hit the CDN.
$cacheDir = __DIR__ . '/imgcache';
if (!is_dir($cacheDir)) { @mkdir($cacheDir, 0755, true); }
$key = $cacheDir . '/' . sha1($u);
$meta = $key . '.ct';

if (is_file($key) && (time() - filemtime($key)) < 7 * 86400) {
    $ct = is_file($meta) ? trim(file_get_contents($meta)) : 'image/jpeg';
    header('Content-Type: ' . $ct);
    header('Cache-Control: public, max-age=604800');
    header('Access-Control-Allow-Origin: *');
    readfile($key);
    exit;
}

$ch = curl_init($u);
curl_setopt_array($ch, [
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_FOLLOWLOCATION => true,
    CURLOPT_MAXREDIRS => 3,
    CURLOPT_TIMEOUT => 20,
    CURLOPT_USERAGENT => 'Mozilla/5.0 (compatible; ParamallImageProxy/1.0)',
]);
$body = curl_exec($ch);
$code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
$ct   = curl_getinfo($ch, CURLINFO_CONTENT_TYPE);
curl_close($ch);

if ($code !== 200 || $body === false || stripos((string)$ct, 'image/') !== 0) {
    http_response_code(502);
    exit('fetch failed');
}

@file_put_contents($key, $body);
@file_put_contents($meta, $ct);

header('Content-Type: ' . $ct);
header('Cache-Control: public, max-age=604800');
header('Access-Control-Allow-Origin: *');
echo $body;
