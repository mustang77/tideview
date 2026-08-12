<?php
declare(strict_types=1);

/**
 * Paramall backend API (single-file, PHP + MySQL).
 * Call: POST https://paramall.h2olaundry.com/api/index.php  with JSON { "action": "...", ... }
 * Token-based auth (no cookies). Prepared statements everywhere.
 */

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
if (($_SERVER['REQUEST_METHOD'] ?? 'GET') === 'OPTIONS') {
    http_response_code(204);
    exit;
}

function fail(int $code, string $msg): never {
    http_response_code($code);
    echo json_encode(['ok' => false, 'error' => $msg]);
    exit;
}
function ok(array $data = []): never {
    echo json_encode(['ok' => true] + $data, JSON_UNESCAPED_UNICODE);
    exit;
}
function sfield(array $a, string $k, int $max = 255): string {
    return mb_substr(trim((string)($a[$k] ?? '')), 0, $max);
}
function ifield(array $a, string $k): int {
    return (int)($a[$k] ?? 0);
}
function newToken(): string {
    return bin2hex(random_bytes(32));
}
function rupiahShort(int $n): string {
    return 'Rp' . number_format($n, 0, ',', '.');
}
function orderOut(array $o): array {
    return [
        'id' => $o['id'], 'name' => $o['name'], 'phone' => $o['phone'], 'addr' => $o['addr'],
        'note' => $o['note'], 'pay' => $o['pay'], 'zone' => $o['zone'],
        'items' => json_decode($o['items'] ?: '[]', true) ?: [],
        'subtotal' => (int)$o['subtotal'], 'ongkir' => (int)$o['ongkir'], 'total' => (int)$o['total'],
        'status' => $o['status'],
        'at' => str_replace(' ', 'T', (string)$o['created_at']),
        'updated_at' => str_replace(' ', 'T', (string)$o['updated_at']),
    ];
}
function authUser(PDO $pdo, array $body): array {
    $token = '';
    $hdr = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
    if (preg_match('/Bearer\s+(.+)/i', $hdr, $m)) {
        $token = trim($m[1]);
    }
    if ($token === '') {
        $token = trim((string)($body['token'] ?? ''));
    }
    if ($token === '') {
        fail(401, 'Perlu login');
    }
    $st = $pdo->prepare('SELECT * FROM users WHERE token = ? LIMIT 1');
    $st->execute([$token]);
    $u = $st->fetch();
    if (!$u) {
        fail(401, 'Sesi tidak valid, silakan login ulang');
    }
    return $u;
}
function requireAdmin(array $cfg, array $body): void {
    $pass = (string)($body['admin_pass'] ?? ($_GET['admin_pass'] ?? ''));
    if (!hash_equals((string)$cfg['admin_pass'], $pass)) {
        fail(403, 'Passcode admin salah');
    }
}
// Drivers use their own passcode; the admin passcode also works (admin can do anything).
function requireDriver(array $cfg, array $body): void {
    $pass = (string)($body['driver_pass'] ?? ($body['admin_pass'] ?? ($_GET['driver_pass'] ?? '')));
    $driver = (string)($cfg['driver_pass'] ?? '');
    $admin = (string)($cfg['admin_pass'] ?? '');
    if (($driver !== '' && hash_equals($driver, $pass)) || ($admin !== '' && hash_equals($admin, $pass))) {
        return;
    }
    fail(403, 'Passcode driver salah');
}

// Human-friendly push copy for each status.
function statusMessage(string $status): string {
    switch ($status) {
        case 'Diproses': return 'Pesananmu sedang kami siapkan 🛒';
        case 'Diantar':  return 'Driver sedang mengantar pesananmu 🛵';
        case 'Selesai':  return 'Pesanan selesai. Terima kasih! ✅';
        default:         return 'Status pesanan diperbarui: ' . $status;
    }
}

// Notify the customer who owns an order that its status changed. Best-effort.
function notifyOrderOwner(PDO $pdo, array $cfg, string $orderId, string $status): void {
    try {
        $st = $pdo->prepare('SELECT user_id FROM orders WHERE id = ? LIMIT 1');
        $st->execute([$orderId]);
        $row = $st->fetch();
        if (!$row) {
            return;
        }
        $ts = $pdo->prepare('SELECT token FROM device_tokens WHERE user_id = ?');
        $ts->execute([(int)$row['user_id']]);
        $tokens = array_column($ts->fetchAll(), 'token');
        fcmNotifyTokens($cfg, $tokens, 'Pesanan #' . $orderId, statusMessage($status), [
            'orderId' => $orderId, 'status' => $status, 'type' => 'order_status',
        ]);
    } catch (Throwable $e) {
        // Ignore.
    }
}

$raw = file_get_contents('php://input');
$body = json_decode($raw ?: '{}', true);
if (!is_array($body)) {
    $body = [];
}
$action = (string)($_GET['action'] ?? ($body['action'] ?? ''));

// Reachability check that does not need the database.
if ($action === 'health') {
    ok(['service' => 'paramall-api', 'time' => date('c')]);
}

$configFile = __DIR__ . '/config.php';
if (!file_exists($configFile)) {
    fail(500, 'config.php belum dibuat (salin dari config.sample.php)');
}
$cfg = require $configFile;
require __DIR__ . '/fcm.php';

try {
    $pdo = new PDO(
        "mysql:host={$cfg['db_host']};dbname={$cfg['db_name']};charset=utf8mb4",
        $cfg['db_user'],
        $cfg['db_pass'],
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC]
    );
} catch (Throwable $e) {
    fail(500, 'Koneksi database gagal. Cek config.php.');
}

switch ($action) {
    case 'register': {
        $name = sfield($body, 'name', 80);
        $phone = sfield($body, 'phone', 20);
        $pin = (string)($body['pin'] ?? '');
        if ($name === '' || $phone === '' || strlen($pin) < 4) {
            fail(400, 'Lengkapi nama, nomor HP, dan PIN (min. 4 angka)');
        }
        $st = $pdo->prepare('SELECT id FROM users WHERE phone = ?');
        $st->execute([$phone]);
        if ($st->fetch()) {
            fail(409, 'Nomor HP sudah terdaftar. Silakan masuk.');
        }
        $token = newToken();
        $st = $pdo->prepare('INSERT INTO users (name, phone, pin_hash, token, created_at) VALUES (?,?,?,?,NOW())');
        $st->execute([$name, $phone, password_hash($pin, PASSWORD_DEFAULT), $token]);
        ok(['token' => $token, 'name' => $name, 'phone' => $phone, 'address' => '']);
    }

    case 'login': {
        $phone = sfield($body, 'phone', 20);
        $pin = (string)($body['pin'] ?? '');
        if ($phone === '' || $pin === '') {
            fail(400, 'Isi nomor HP dan PIN');
        }
        $st = $pdo->prepare('SELECT * FROM users WHERE phone = ? LIMIT 1');
        $st->execute([$phone]);
        $u = $st->fetch();
        if (!$u || !password_verify($pin, $u['pin_hash'])) {
            fail(401, 'Nomor HP atau PIN salah');
        }
        $token = newToken();
        $pdo->prepare('UPDATE users SET token = ? WHERE id = ?')->execute([$token, $u['id']]);
        ok(['token' => $token, 'name' => $u['name'], 'phone' => $u['phone'], 'address' => $u['address']]);
    }

    case 'me': {
        $u = authUser($pdo, $body);
        ok(['name' => $u['name'], 'phone' => $u['phone'], 'address' => $u['address']]);
    }

    case 'save_profile': {
        $u = authUser($pdo, $body);
        $name = sfield($body, 'name', 80);
        $address = sfield($body, 'address', 300);
        $pdo->prepare('UPDATE users SET name = ?, address = ? WHERE id = ?')
            ->execute([$name !== '' ? $name : $u['name'], $address, $u['id']]);
        ok();
    }

    case 'place_order': {
        $u = authUser($pdo, $body);
        $items = $body['items'] ?? [];
        if (!is_array($items) || count($items) === 0) {
            fail(400, 'Keranjang kosong');
        }
        $clean = [];
        foreach ($items as $it) {
            if (!is_array($it)) {
                continue;
            }
            $clean[] = [
                'name' => mb_substr(trim((string)($it['name'] ?? '')), 0, 200),
                'price' => (int)($it['price'] ?? 0),
                'qty' => max(1, (int)($it['qty'] ?? 1)),
            ];
        }
        $id = 'PM' . date('ymd-His') . random_int(10, 99);
        $st = $pdo->prepare(
            'INSERT INTO orders (id, user_id, name, phone, addr, note, pay, zone, items, subtotal, ongkir, total, status, created_at, updated_at)
             VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,NOW(),NOW())'
        );
        $addr = sfield($body, 'addr', 300);
        $st->execute([
            $id, (int)$u['id'],
            sfield($body, 'name', 80) ?: $u['name'],
            sfield($body, 'phone', 20) ?: $u['phone'],
            $addr,
            sfield($body, 'note', 300),
            sfield($body, 'pay', 20),
            sfield($body, 'zone', 40),
            json_encode($clean, JSON_UNESCAPED_UNICODE),
            ifield($body, 'subtotal'), ifield($body, 'ongkir'), ifield($body, 'total'),
            'Diterima',
        ]);
        if ($addr !== '') {
            $pdo->prepare('UPDATE users SET address = ? WHERE id = ?')->execute([$addr, $u['id']]);
        }
        // Alert the delivery team (devices subscribed to the 'staff' topic).
        fcmNotifyTopic($cfg, 'staff', 'Pesanan baru masuk 🛎️',
            sprintf('#%s • %s • %s', $id, $u['name'], rupiahShort(ifield($body, 'total'))),
            ['orderId' => $id, 'type' => 'new_order']);
        ok(['id' => $id]);
    }

    case 'my_orders': {
        $u = authUser($pdo, $body);
        $st = $pdo->prepare('SELECT * FROM orders WHERE user_id = ? ORDER BY created_at DESC LIMIT 100');
        $st->execute([(int)$u['id']]);
        ok(['orders' => array_map('orderOut', $st->fetchAll())]);
    }

    case 'admin_orders': {
        requireAdmin($cfg, $body);
        $st = $pdo->query('SELECT * FROM orders ORDER BY created_at DESC LIMIT 500');
        ok(['orders' => array_map('orderOut', $st->fetchAll())]);
    }

    case 'admin_set_status': {
        requireAdmin($cfg, $body);
        $id = sfield($body, 'id', 40);
        $status = sfield($body, 'status', 40);
        if ($id === '' || $status === '') {
            fail(400, 'id & status wajib');
        }
        $pdo->prepare('UPDATE orders SET status = ?, updated_at = NOW() WHERE id = ?')->execute([$status, $id]);
        notifyOrderOwner($pdo, $cfg, $id, $status);
        ok();
    }

    // ---- Driver mode ----
    case 'driver_orders': {
        requireDriver($cfg, $body);
        // Active jobs only (anything not yet finished), oldest first so the queue is FIFO.
        $st = $pdo->query("SELECT * FROM orders WHERE status <> 'Selesai' ORDER BY created_at ASC LIMIT 200");
        ok(['orders' => array_map('orderOut', $st->fetchAll())]);
    }

    case 'driver_set_status': {
        requireDriver($cfg, $body);
        $id = sfield($body, 'id', 40);
        $status = sfield($body, 'status', 40);
        // Drivers may only pick up (Diantar) or complete (Selesai).
        if (!in_array($status, ['Diantar', 'Selesai'], true)) {
            fail(400, 'Status tidak diizinkan untuk driver');
        }
        if ($id === '') {
            fail(400, 'id wajib');
        }
        $pdo->prepare('UPDATE orders SET status = ?, updated_at = NOW() WHERE id = ?')->execute([$status, $id]);
        notifyOrderOwner($pdo, $cfg, $id, $status);
        ok();
    }

    // ---- Push notification tokens ----
    case 'register_token': {
        $u = authUser($pdo, $body);
        $token = sfield($body, 'device_token', 255);
        $platform = sfield($body, 'platform', 20);
        if ($token === '') {
            fail(400, 'device_token wajib');
        }
        // Upsert by token (a device can move between accounts).
        $st = $pdo->prepare(
            'INSERT INTO device_tokens (user_id, token, platform, role, updated_at)
             VALUES (?,?,?,?,NOW())
             ON DUPLICATE KEY UPDATE user_id = VALUES(user_id), platform = VALUES(platform), updated_at = NOW()'
        );
        $st->execute([(int)$u['id'], $token, $platform, 'customer']);
        ok();
    }

    case 'unregister_token': {
        $token = sfield($body, 'device_token', 255);
        if ($token !== '') {
            $pdo->prepare('DELETE FROM device_tokens WHERE token = ?')->execute([$token]);
        }
        ok();
    }

    default:
        fail(404, 'Action tidak dikenal: ' . $action);
}
