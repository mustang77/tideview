<?php
// Copy this file to  config.php  and fill in YOUR values.
// Create the database + user in Webuzo (MySQL Databases), then import schema.sql.
// NEVER commit config.php.
return [
    'db_host'    => 'localhost',
    'db_name'    => 'YOUR_DB_NAME',
    'db_user'    => 'YOUR_DB_USER',
    'db_pass'    => 'YOUR_DB_PASSWORD',
    // Passcode for the admin endpoints (same as the in-app / web admin).
    'admin_pass' => 'paramall2026',
    // Passcode for drivers (in-app Driver mode). Give this to your delivery team.
    'driver_pass' => 'driver2026',
    // Firebase project id (for push). Fill in after you create the Firebase project,
    // or leave blank — notifications just no-op until this + fcm-service-account.json exist.
    'fcm_project_id' => '',
];
