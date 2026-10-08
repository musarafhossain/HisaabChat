-- Runs once when the Docker MariaDB volume is first created.
CREATE DATABASE IF NOT EXISTS hisaabchat_test CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON hisaabchat_test.* TO 'hisaabchat'@'%';
FLUSH PRIVILEGES;
