-- Paramall backend schema. Import once via phpMyAdmin (Webuzo) or the MySQL CLI.

CREATE TABLE IF NOT EXISTS users (
  id        INT AUTO_INCREMENT PRIMARY KEY,
  name      VARCHAR(80)  NOT NULL,
  phone     VARCHAR(20)  NOT NULL UNIQUE,
  pin_hash  VARCHAR(255) NOT NULL,
  address   VARCHAR(300) NOT NULL DEFAULT '',
  token     VARCHAR(80)  NOT NULL DEFAULT '',
  failed_attempts INT     NOT NULL DEFAULT 0,   -- consecutive wrong-PIN count
  locked_until    DATETIME NULL,                -- login locked until this time
  created_at DATETIME    NOT NULL,
  INDEX idx_token (token)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- If your users table already exists, add the brute-force-guard columns with:
--   ALTER TABLE users
--     ADD COLUMN failed_attempts INT NOT NULL DEFAULT 0,
--     ADD COLUMN locked_until    DATETIME NULL;

CREATE TABLE IF NOT EXISTS orders (
  id         VARCHAR(40) PRIMARY KEY,
  user_id    INT NOT NULL,
  name       VARCHAR(80),
  phone      VARCHAR(20),
  addr       VARCHAR(300),
  note       VARCHAR(300),
  pay        VARCHAR(20),
  zone       VARCHAR(40),
  items      LONGTEXT,
  subtotal   INT,
  ongkir     INT,
  total      INT,
  status     VARCHAR(40) NOT NULL DEFAULT 'Diterima',
  driver_lat DECIMAL(10,7) NULL,
  driver_lng DECIMAL(10,7) NULL,
  driver_at  DATETIME NULL,
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL,
  INDEX idx_user (user_id),
  INDEX idx_created (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- If your orders table already exists, add the live-tracking columns with:
--   ALTER TABLE orders
--     ADD COLUMN driver_lat DECIMAL(10,7) NULL,
--     ADD COLUMN driver_lng DECIMAL(10,7) NULL,
--     ADD COLUMN driver_at  DATETIME NULL;

-- Promo banners (managed from the in-app Admin → Kelola Promo).
CREATE TABLE IF NOT EXISTS promos (
  id         INT AUTO_INCREMENT PRIMARY KEY,
  title      VARCHAR(120) NOT NULL,
  subtitle   VARCHAR(300) NOT NULL DEFAULT '',
  emoji      VARCHAR(16)  NOT NULL DEFAULT '🎉',
  color1     VARCHAR(9)   NOT NULL DEFAULT '#2E9C6E',
  color2     VARCHAR(9)   NOT NULL DEFAULT '#12543A',
  action     VARCHAR(60)  NOT NULL DEFAULT '',
  is_popup   TINYINT      NOT NULL DEFAULT 0,
  sort_order INT          NOT NULL DEFAULT 0,
  active     TINYINT      NOT NULL DEFAULT 1,
  updated_at DATETIME     NOT NULL,
  INDEX idx_active (active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Firebase Cloud Messaging device tokens (for push notifications).
CREATE TABLE IF NOT EXISTS device_tokens (
  id         INT AUTO_INCREMENT PRIMARY KEY,
  user_id    INT NOT NULL DEFAULT 0,        -- 0 = staff/driver device (not tied to a customer)
  token      VARCHAR(255) NOT NULL UNIQUE,
  platform   VARCHAR(20) NOT NULL DEFAULT '',
  role       VARCHAR(20) NOT NULL DEFAULT 'customer', -- 'customer' | 'staff'
  updated_at DATETIME NOT NULL,
  INDEX idx_user (user_id),
  INDEX idx_role (role)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
