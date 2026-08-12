-- Paramall backend schema. Import once via phpMyAdmin (Webuzo) or the MySQL CLI.

CREATE TABLE IF NOT EXISTS users (
  id        INT AUTO_INCREMENT PRIMARY KEY,
  name      VARCHAR(80)  NOT NULL,
  phone     VARCHAR(20)  NOT NULL UNIQUE,
  pin_hash  VARCHAR(255) NOT NULL,
  address   VARCHAR(300) NOT NULL DEFAULT '',
  token     VARCHAR(80)  NOT NULL DEFAULT '',
  created_at DATETIME    NOT NULL,
  INDEX idx_token (token)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

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
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL,
  INDEX idx_user (user_id),
  INDEX idx_created (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
