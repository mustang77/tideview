<?php
declare(strict_types=1);

/**
 * Minimal Firebase Cloud Messaging (HTTP v1) sender.
 *
 * Fully optional: if `fcm-service-account.json` is missing or the project id is
 * blank, every function here quietly does nothing — the rest of the API keeps
 * working. Drop the service-account file in this folder and set
 * `fcm_project_id` in config.php and pushes start flowing automatically.
 *
 * The service-account JSON comes from the Firebase console:
 *   Project settings → Service accounts → Generate new private key.
 * Keep it secret — it is git-ignored.
 */

function fcmServiceAccountPath(): string {
    return __DIR__ . '/fcm-service-account.json';
}

function fcmEnabled(array $cfg): bool {
    return trim((string)($cfg['fcm_project_id'] ?? '')) !== '' && is_file(fcmServiceAccountPath());
}

/** Build a short-lived OAuth access token from the service account (JWT bearer grant). */
function fcmAccessToken(): ?string {
    $raw = @file_get_contents(fcmServiceAccountPath());
    if ($raw === false) {
        return null;
    }
    $sa = json_decode($raw, true);
    if (!is_array($sa) || empty($sa['client_email']) || empty($sa['private_key'])) {
        return null;
    }
    $now = time();
    $header = ['alg' => 'RS256', 'typ' => 'JWT'];
    $claims = [
        'iss'   => $sa['client_email'],
        'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
        'aud'   => 'https://oauth2.googleapis.com/token',
        'iat'   => $now,
        'exp'   => $now + 3600,
    ];
    $b64 = static fn(string $s): string => rtrim(strtr(base64_encode($s), '+/', '-_'), '=');
    $signingInput = $b64(json_encode($header)) . '.' . $b64(json_encode($claims));
    $sig = '';
    if (!openssl_sign($signingInput, $sig, $sa['private_key'], OPENSSL_ALGO_SHA256)) {
        return null;
    }
    $jwt = $signingInput . '.' . $b64($sig);

    $ch = curl_init('https://oauth2.googleapis.com/token');
    curl_setopt_array($ch, [
        CURLOPT_POST => true,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_TIMEOUT => 15,
        CURLOPT_POSTFIELDS => http_build_query([
            'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
            'assertion'  => $jwt,
        ]),
    ]);
    $resp = curl_exec($ch);
    curl_close($ch);
    if (!is_string($resp)) {
        return null;
    }
    $data = json_decode($resp, true);
    return is_array($data) ? ($data['access_token'] ?? null) : null;
}

/** POST one message to the FCM v1 endpoint. Returns HTTP status (or 0 on failure). */
function fcmPost(string $projectId, string $accessToken, array $message): int {
    $ch = curl_init("https://fcm.googleapis.com/v1/projects/{$projectId}/messages:send");
    curl_setopt_array($ch, [
        CURLOPT_POST => true,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_TIMEOUT => 15,
        CURLOPT_HTTPHEADER => [
            'Authorization: Bearer ' . $accessToken,
            'Content-Type: application/json',
        ],
        CURLOPT_POSTFIELDS => json_encode(['message' => $message], JSON_UNESCAPED_UNICODE),
    ]);
    curl_exec($ch);
    $code = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    return $code;
}

/**
 * Send a notification to a set of device tokens. Silently no-ops when FCM is
 * not configured. Never throws — notification problems must not break an order.
 */
function fcmNotifyTokens(array $cfg, array $tokens, string $title, string $body, array $data = []): void {
    if (!fcmEnabled($cfg) || count($tokens) === 0) {
        return;
    }
    try {
        $token = fcmAccessToken();
        if ($token === null) {
            return;
        }
        $projectId = (string)$cfg['fcm_project_id'];
        $strData = [];
        foreach ($data as $k => $v) {
            $strData[(string)$k] = (string)$v; // FCM data values must be strings
        }
        foreach (array_unique($tokens) as $t) {
            if ($t === '') {
                continue;
            }
            fcmPost($projectId, $token, [
                'token' => $t,
                'notification' => ['title' => $title, 'body' => $body],
                'data' => $strData,
                'android' => ['priority' => 'high', 'notification' => ['channel_id' => 'paramall_orders']],
            ]);
        }
    } catch (Throwable $e) {
        // Ignore — pushes are best-effort.
    }
}

/** Send a notification to a topic (e.g. 'staff' for new-order alerts). */
function fcmNotifyTopic(array $cfg, string $topic, string $title, string $body, array $data = []): void {
    if (!fcmEnabled($cfg) || $topic === '') {
        return;
    }
    try {
        $token = fcmAccessToken();
        if ($token === null) {
            return;
        }
        $strData = [];
        foreach ($data as $k => $v) {
            $strData[(string)$k] = (string)$v;
        }
        fcmPost((string)$cfg['fcm_project_id'], $token, [
            'topic' => $topic,
            'notification' => ['title' => $title, 'body' => $body],
            'data' => $strData,
            'android' => ['priority' => 'high', 'notification' => ['channel_id' => 'paramall_orders']],
        ]);
    } catch (Throwable $e) {
        // Ignore.
    }
}
