#!/bin/bash
# =============================================================================
# CTF MGP — DESPLIEGUE MAESTRO: 5 Retos Criptografía (R6-R10) v2
# Ubuntu Server 24.04 LTS
# Acceso: SSH (/home/ctf/cripto/) + Portal web (/cripto/)
# Sin README.txt — pistas van en la plataforma CyberRanges
# Ejecutar: sudo bash deploy_cripto_MAESTRO.sh
# =============================================================================
set -e

VERDE="\e[32m"; AMARILLO="\e[33m"; ROJO="\e[31m"
AZUL="\e[34m"; NEGRITA="\e[1m"; RESET="\e[0m"

[ "$EUID" -ne 0 ] && { echo -e "${ROJO}Ejecutar como root: sudo bash $0${RESET}"; exit 1; }

echo -e "${AZUL}${NEGRITA}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║   CTF MGP — Deploy Maestro Criptografía (R6-R10) v2         ║"
echo "║   Ubuntu 24.04 LTS  |  Sin README  |  SSH + Web             ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${RESET}"

# =============================================================================
# PASO 1 — DEPENDENCIAS
# =============================================================================
echo -e "${AMARILLO}[1/8] Instalando dependencias...${RESET}"
apt-get update -qq
apt-get install -y -qq python3 python3-pip openssl hashcat john 2>/dev/null || true
pip3 install pycryptodome --break-system-packages --quiet 2>/dev/null || \
    apt-get install -y -qq python3-pycryptodome 2>/dev/null || true
echo -e "${VERDE}    [OK] Dependencias instaladas${RESET}"

# =============================================================================
# PASO 2 — ESTRUCTURA DE DIRECTORIOS
# =============================================================================
echo -e "${AMARILLO}[2/8] Creando estructura de directorios...${RESET}"
mkdir -p /home/ctf/cripto/{cesar,base64,hash,vigenere,rsa}
mkdir -p /var/www/html/cripto/{cesar,base64,hash,vigenere,rsa}
echo -e "${VERDE}    [OK] Directorios creados${RESET}"

# =============================================================================
# PASO 3 — RETO 6: Cifrado César
# Flag: Comciberdef{cesar_cipher_breaker_2026}  |  Shift: 13 (ROT13)
# =============================================================================
echo -e "${AMARILLO}[3/8] Desplegando Reto 6 — César...${RESET}"

cat > /home/ctf/cripto/cesar/mensaje.txt <<'EOF'
CLASIFICADO - NIVEL 1
Servicio de Comunicaciones Navales - DIVCOMAR
Origen: Base Naval del Callao | Fecha: 15-ENE-2026

----------------------------------------------------------------------
MENSAJE CIFRADO:

Yn frthevqnq qr ynf pbzhavpnpvbarf aninyrf rf shaqnzragny.
Ry bsvpvny n pnetb qror erpbeqne dhr yn pynir rf
Pbzpvoreqrs{prfne_pvcure_oernxre_2026}
l genafzvgveyn fbyb cbe pnanyrf frthebf.

----------------------------------------------------------------------
EOF

cp /home/ctf/cripto/cesar/mensaje.txt /var/www/html/cripto/cesar/
echo -e "${VERDE}    [OK] Reto 6 desplegado (shift=13)${RESET}"

# =============================================================================
# PASO 4 — RETO 7: Base64 multicapa
# Flag: Comciberdef{base64_multi_layer_decoded_2026}  |  3 capas
# =============================================================================
echo -e "${AMARILLO}[4/8] Desplegando Reto 7 — Base64...${RESET}"

python3 -c "
import base64
flag = 'Comciberdef{base64_multi_layer_decoded_2026}'
l1 = base64.b64encode(flag.encode()).decode()
l2 = base64.b64encode(l1.encode()).decode()
l3 = base64.b64encode(l2.encode()).decode()
txt  = 'INTERCEPTADO - SISTEMA DE COMUNICACIONES MGP\n'
txt += '=============================================\n'
txt += 'Se ha capturado el siguiente dato codificado en transito.\n'
txt += 'Decodifique para obtener la informacion clasificada.\n\n'
txt += l3 + '\n'
open('/home/ctf/cripto/base64/encoded.txt','w').write(txt)
open('/var/www/html/cripto/base64/encoded.txt','w').write(txt)
print('[OK] encoded.txt generado y verificado')
# Verificar
d1=base64.b64decode(l3).decode()
d2=base64.b64decode(d1.strip()).decode()
d3=base64.b64decode(d2.strip()).decode()
assert d3==flag, f'Error: {d3}'
print(f'[OK] Verificado: {d3}')
"
echo -e "${VERDE}    [OK] Reto 7 desplegado (3 capas Base64)${RESET}"

# =============================================================================
# PASO 5 — RETO 8: Cracking de Hash MD5
# Flag: Comciberdef{MGP_Callao2026}  |  MD5 de MGP_Callao2026
# hash.txt SIN comentarios (limpio para hashcat/john)
# =============================================================================
echo -e "${AMARILLO}[5/8] Desplegando Reto 8 — Hash...${RESET}"

# Hash limpio — sin comentarios # para evitar confusión con hashcat
echo "7a8f8d532e4a2229b0e843b02e962387" > /home/ctf/cripto/hash/hash.txt

# Wordlist con la contraseña objetivo
cat > /home/ctf/cripto/hash/wordlist.txt <<'EOF'
password
123456
admin
letmein
naval2026
marina
callao
pacifico
defensa
ciberdefensa
MGP2026
MGP_Lima2026
MGP_Callao2026
MGP_Piura2026
Callao2026
Lima_Naval
ContrasenaNaval
SistemasMGP
AccesoNaval
OficialMGP
password123
abc123
qwerty
iloveyou
monkey
dragon
master
welcome
shadow
football
baseball
military
soldier
navy2026
naval123
peru2026
mgp123
EOF

cp /home/ctf/cripto/hash/hash.txt     /var/www/html/cripto/hash/
cp /home/ctf/cripto/hash/wordlist.txt /var/www/html/cripto/hash/

# Verificar hash
HASH_OK=$(python3 -c "import hashlib; print(hashlib.md5('MGP_Callao2026'.encode()).hexdigest())")
echo -e "${VERDE}    [OK] Reto 8 desplegado — Hash: $HASH_OK${RESET}"

# =============================================================================
# PASO 6 — RETO 9: Cifrado Vigenère
# Flag: Comciberdef{vigenere_key_is_marina_2026}  |  Clave: MARINA
# Formato: cabecera + mensaje cifrado + instrucción mínima (sin pistas)
# =============================================================================
echo -e "${AMARILLO}[6/8] Desplegando Reto 9 — Vigenère...${RESET}"

python3 << 'PYEOF'
import string

def vig_enc(text, key):
    r=''; key=key.upper(); ki=0
    for c in text:
        if c.upper() in string.ascii_uppercase:
            s=ord(key[ki%len(key)])-ord('A')
            b=ord('A') if c.isupper() else ord('a')
            r+=chr((ord(c)-b+s)%26+b); ki+=1
        else: r+=c
    return r

def vig_dec(text, key):
    r=''; key=key.upper(); ki=0
    for c in text:
        if c.upper() in string.ascii_uppercase:
            s=ord(key[ki%len(key)])-ord('A')
            b=ord('A') if c.isupper() else ord('a')
            r+=chr((ord(c)-b-s)%26+b); ki+=1
        else: r+=c
    return r

key = 'MARINA'
# Texto plano ASCII puro (sin tildes para que Vigenere funcione correctamente)
plain = (
    "El comando de ciberdefensa protege las redes navales del Pacifico Sur. "
    "Acceso nivel tres requerido. "
    "La contrasena de acceso al sistema clasificado es "
    "Comciberdef{vigenere_key_is_marina_2026}. "
    "Custodiar con maxima reserva. "
    "Solo el personal con clearance NIVEL-3 puede acceder a esta informacion."
)
cipher = vig_enc(plain, key)

# Verificar antes de escribir
assert vig_dec(cipher, key) == plain, "Error en cifrado/descifrado"
assert 'Comciberdef{vigenere_key_is_marina_2026}' in vig_dec(cipher, key)

# Formato: igual al que modificó el usuario — cabecera + cifrado + instrucción mínima
content  = "CLASIFICADO - NIVEL 3\n"
content += "Servicio de Inteligencia Naval - DIRINA\n"
content += "Origen: Base Naval del Callao | Ref: DIRINA-2026-0147\n"
content += "----------------------------------------------------------------------\n"
content += "MENSAJE CIFRADO:\n"
content += cipher + "\n"
content += "----------------------------------------------------------------------\n"
content += "Instrucciones:\n"
content += "  - Cifrado polialfabetico. La clave se repite a lo largo del mensaje.\n"

with open('/home/ctf/cripto/vigenere/mensaje.txt','w',encoding='ascii') as f:
    f.write(content)
with open('/var/www/html/cripto/vigenere/mensaje.txt','w',encoding='ascii') as f:
    f.write(content)

print(f"[OK] Vigenere escrito correctamente")
print(f"[OK] Cifrado[:60]: {cipher[:60]}")
print(f"[OK] Flag en descifrado: {'Comciberdef' in vig_dec(cipher,key)}")
PYEOF

echo -e "${VERDE}    [OK] Reto 9 desplegado (clave=MARINA, formato limpio)${RESET}"

# =============================================================================
# PASO 7 — RETO 10: RSA Débil (Ataque de Fermat)
# Flag: Comciberdef{rsa_fermat_2026}  |  p y q cercanos (diff=180)
# =============================================================================
echo -e "${AMARILLO}[7/8] Desplegando Reto 10 — RSA Débil...${RESET}"

python3 << 'PYEOF'
import math
from Crypto.PublicKey import RSA
from Crypto.Util.number import long_to_bytes, bytes_to_long

# p y q muy cercanos — Fermat los factoriza en 0 pasos
p = 57896044618658097711785492504343953926634992332820282019728792003956564820063
q = 57896044618658097711785492504343953926634992332820282019728792003956564820243
n = p * q
e = 65537
d = pow(e, -1, (p-1)*(q-1))

# Construir y exportar clave pública
key = RSA.construct((n, e, d, p, q))
pub_pem = key.publickey().export_key().decode()
with open('/home/ctf/cripto/rsa/public.pem','w') as f:
    f.write(pub_pem + '\n')

# Cifrar la flag
flag  = b'Comciberdef{rsa_fermat_2026}'
m_int = bytes_to_long(flag)
c_int = pow(m_int, e, n)
c_bytes = long_to_bytes(c_int)

# Guardar binario y hex
with open('/home/ctf/cripto/rsa/mensaje.enc','wb') as f:
    f.write(c_bytes)
with open('/home/ctf/cripto/rsa/mensaje.enc.hex','w') as f:
    f.write(c_bytes.hex() + '\n')

# Verificar con Fermat
a  = math.isqrt(n) + 1
b2 = a*a - n
b  = math.isqrt(b2)
while b*b != b2:
    a += 1; b2 = a*a - n; b = math.isqrt(b2)
p_f, q_f = a-b, a+b
d_f  = pow(e, -1, (p_f-1)*(q_f-1))
flag_dec = pow(c_int, d_f, n).to_bytes(len(flag),'big')

print(f"[OK] Clave publica generada")
print(f"[OK] Cifrado hex: {c_bytes.hex()[:32]}...")
print(f"[OK] Fermat factoriza: {p_f==p}")
print(f"[OK] Flag descifrada: {flag_dec}")

# Copiar al portal web
import shutil
for f in ['public.pem','mensaje.enc','mensaje.enc.hex']:
    shutil.copy(f'/home/ctf/cripto/rsa/{f}', f'/var/www/html/cripto/rsa/{f}')
print("[OK] Archivos copiados al portal web")
PYEOF

echo -e "${VERDE}    [OK] Reto 10 desplegado (RSA Fermat)${RESET}"

# =============================================================================
# PASO 8 — PORTAL WEB /cripto/ — sin README, con mensaje.enc en R10
# =============================================================================
echo -e "${AMARILLO}[8/8] Desplegando portal web /cripto/...${RESET}"

cat > /var/www/html/cripto/index.html <<'HTMLEOF'
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>COMCIBERDEF — Retos de Criptografía</title>
<style>
*{box-sizing:border-box;margin:0;padding:0}
body{background:#0a0f1e;color:#c9d1d9;font-family:'Segoe UI',sans-serif;min-height:100vh}
header{background:#161b27;border-bottom:2px solid #1f6feb;padding:18px 40px;
       display:flex;align-items:center;gap:16px}
header h1{font-size:22px;color:#58a6ff;font-weight:700;letter-spacing:1px}
header span{font-size:12px;color:#8b949e;margin-left:auto}
.container{max-width:960px;margin:40px auto;padding:0 24px}
h2{font-size:16px;color:#58a6ff;margin-bottom:20px;text-transform:uppercase;
   letter-spacing:2px;border-bottom:1px solid #21262d;padding-bottom:8px}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(280px,1fr));gap:16px}
.card{background:#161b27;border:1px solid #21262d;border-radius:10px;
      padding:24px;transition:.2s}
.card:hover{border-color:#1f6feb;transform:translateY(-2px)}
.card-header{display:flex;align-items:center;gap:12px;margin-bottom:12px}
.num{background:#1f6feb;color:#fff;font-size:12px;font-weight:700;
     padding:4px 10px;border-radius:20px}
.nivel{font-size:11px;font-weight:600;padding:3px 8px;border-radius:10px}
.basico{background:#1e3a1e;color:#3fb950}
.intermedio{background:#3d2a00;color:#d29922}
.avanzado{background:#3d0000;color:#f85149}
.card h3{font-size:15px;color:#e6edf3;margin-bottom:6px}
.card p{font-size:12px;color:#8b949e;line-height:1.5;margin-bottom:14px}
.files{display:flex;flex-wrap:wrap;gap:6px}
.file-link{background:#0d1117;border:1px solid #30363d;border-radius:6px;
           padding:4px 10px;font-size:11px;color:#58a6ff;text-decoration:none;
           transition:.15s}
.file-link:hover{border-color:#58a6ff}
.intro{background:#161b27;border:1px solid #21262d;border-radius:10px;
       padding:20px 24px;margin-bottom:28px;font-size:14px;color:#8b949e;
       line-height:1.6}
.intro strong{color:#e6edf3}
footer{text-align:center;padding:24px;font-size:11px;color:#484f58;
       border-top:1px solid #21262d;margin-top:40px}
</style>
</head>
<body>
<header>
  <h1>&#128272; COMCIBERDEF — Portal de Criptografía</h1>
  <span>SISTEMA INTERNO — CTF 2026</span>
</header>
<div class="container">
  <div class="intro">
    <strong>Instrucciones:</strong> Descarga los archivos de cada reto y analízalos
    en tu máquina Kali. También puedes acceder via SSH al servidor
    en <strong>/home/ctf/cripto/</strong>.
  </div>
  <h2>Retos disponibles</h2>
  <div class="grid">

    <div class="card">
      <div class="card-header">
        <span class="num">R6</span>
        <span class="nivel basico">Básico</span>
      </div>
      <h3>Cifrado César</h3>
      <p>Mensaje interceptado cifrado con sustitución alfabética clásica.
         Identifica el desplazamiento y descifra.</p>
      <div class="files">
        <a class="file-link" href="cesar/mensaje.txt">mensaje.txt</a>
      </div>
    </div>

    <div class="card">
      <div class="card-header">
        <span class="num">R7</span>
        <span class="nivel basico">Básico</span>
      </div>
      <h3>Decodificación Base64</h3>
      <p>Dato codificado capturado en tránsito. El sistema aplica
         codificación repetida antes de transmitir.</p>
      <div class="files">
        <a class="file-link" href="base64/encoded.txt">encoded.txt</a>
      </div>
    </div>

    <div class="card">
      <div class="card-header">
        <span class="num">R8</span>
        <span class="nivel intermedio">Intermedio</span>
      </div>
      <h3>Cracking de Hash</h3>
      <p>Hash de contraseña obtenido del servidor de autenticación naval.
         Identifica el tipo y crackea.</p>
      <div class="files">
        <a class="file-link" href="hash/hash.txt">hash.txt</a>
        <a class="file-link" href="hash/wordlist.txt">wordlist.txt</a>
      </div>
    </div>

    <div class="card">
      <div class="card-header">
        <span class="num">R9</span>
        <span class="nivel intermedio">Intermedio</span>
      </div>
      <h3>Cifrado Vigenère</h3>
      <p>Comunicación cifrada con Vigenère. Usa análisis de índice de
         coincidencia para encontrar la clave.</p>
      <div class="files">
        <a class="file-link" href="vigenere/mensaje.txt">mensaje.txt</a>
      </div>
    </div>

    <div class="card">
      <div class="card-header">
        <span class="num">R10</span>
        <span class="nivel avanzado">Avanzado</span>
      </div>
      <h3>RSA Débil</h3>
      <p>Mensaje cifrado con RSA. El implementador cometió un error en
         la generación de claves — factoriza n.</p>
      <div class="files">
        <a class="file-link" href="rsa/public.pem">public.pem</a>
        <a class="file-link" href="rsa/mensaje.enc">mensaje.enc</a>
        <a class="file-link" href="rsa/mensaje.enc.hex">mensaje.enc.hex</a>
      </div>
    </div>

  </div>
</div>
<footer>COMCIBERDEF CTF 2026 — Marina de Guerra del Perú</footer>
</body>
</html>
HTMLEOF

chown -R www-data:www-data /var/www/html/cripto
chmod -R 755 /var/www/html/cripto
chown -R root:root /home/ctf/cripto
chmod -R 755 /home/ctf/cripto
echo -e "${VERDE}    [OK] Portal web desplegado (sin README, con mensaje.enc en R10)${RESET}"

# =============================================================================
# VALIDACIÓN FINAL
# =============================================================================
echo ""
echo -e "${AZUL}${NEGRITA}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║               VALIDACIÓN FINAL — Criptografía               ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${RESET}"

PASS=0; FAIL=0
ok()   { echo -e "  ${VERDE}[OK]${RESET}   $1"; PASS=$((PASS+1)); }
fail() { echo -e "  ${ROJO}[FAIL]${RESET} $1"; FAIL=$((FAIL+1)); }
chk_file() { [ -f "$2" ] && ok "$1" || fail "$1 ($2)"; }
chk_web()  {
    local C; C=$(curl -s -o /dev/null -w "%{http_code}" "$2" 2>/dev/null || echo "000")
    [ "$C" = "200" ] && ok "$1 (HTTP $C)" || fail "$1 (got $C)"
}
chk_nofile() { [ ! -f "$2" ] && ok "$1 no existe (correcto)" || fail "$1 AUN EXISTE — eliminar"; }

echo -e "${AMARILLO}── Sin README.txt ───────────────────────────────────${RESET}"
chk_nofile "README cesar SSH"     "/home/ctf/cripto/cesar/README.txt"
chk_nofile "README base64 SSH"    "/home/ctf/cripto/base64/README.txt"
chk_nofile "README hash SSH"      "/home/ctf/cripto/hash/README.txt"
chk_nofile "README vigenere SSH"  "/home/ctf/cripto/vigenere/README.txt"
chk_nofile "README rsa SSH"       "/home/ctf/cripto/rsa/README.txt"
chk_nofile "README cesar web"     "/var/www/html/cripto/cesar/README.txt"
chk_nofile "README vigenere web"  "/var/www/html/cripto/vigenere/README.txt"
chk_nofile "README rsa web"       "/var/www/html/cripto/rsa/README.txt"

echo ""
echo -e "${AMARILLO}── Reto 6: César ────────────────────────────────────${RESET}"
chk_file "mensaje.txt SSH"  "/home/ctf/cripto/cesar/mensaje.txt"
chk_web  "Portal cesar"     "http://localhost/cripto/cesar/mensaje.txt"
CESAR_OK=$(python3 -c "
import string
def dec(t,s):
    r=''
    for c in t:
        if c.upper() in string.ascii_uppercase:
            b=ord('A') if c.isupper() else ord('a')
            r+=chr((ord(c)-b+(26-s))%26+b)
        else: r+=c
    return r
txt=open('/home/ctf/cripto/cesar/mensaje.txt').read()
result=dec(txt,13)
print('1' if 'Comciberdef{cesar_cipher_breaker_2026}' in result else '0')
" 2>/dev/null)
[ "$CESAR_OK" = "1" ] && ok "César descifra con shift=13" || fail "César no descifra"

echo ""
echo -e "${AMARILLO}── Reto 7: Base64 ───────────────────────────────────${RESET}"
chk_file "encoded.txt SSH" "/home/ctf/cripto/base64/encoded.txt"
chk_web  "Portal base64"   "http://localhost/cripto/base64/encoded.txt"
B64_OK=$(python3 -c "
import base64
lines=open('/home/ctf/cripto/base64/encoded.txt').readlines()
for line in lines:
    line=line.strip()
    if line and ' ' not in line and len(line)>20:
        try:
            d1=base64.b64decode(line).decode()
            d2=base64.b64decode(d1.strip()).decode()
            d3=base64.b64decode(d2.strip()).decode()
            print('1' if 'Comciberdef{base64_multi_layer_decoded_2026}' in d3 else '0')
            break
        except: pass
" 2>/dev/null)
[ "$B64_OK" = "1" ] && ok "Base64 × 3 decodifica flag" || fail "Base64 no decodifica"

echo ""
echo -e "${AMARILLO}── Reto 8: Hash ─────────────────────────────────────${RESET}"
chk_file "hash.txt SSH"     "/home/ctf/cripto/hash/hash.txt"
chk_file "wordlist.txt SSH" "/home/ctf/cripto/hash/wordlist.txt"
chk_web  "Portal hash"      "http://localhost/cripto/hash/hash.txt"
# Verificar que hash.txt NO tiene comentarios #
HASH_CLEAN=$(grep "^#" /home/ctf/cripto/hash/hash.txt 2>/dev/null | wc -l)
[ "$HASH_CLEAN" -eq 0 ] && ok "hash.txt limpio (sin comentarios #)" || fail "hash.txt tiene comentarios #"
HASH_OK=$(python3 -c "
import hashlib
h=hashlib.md5('MGP_Callao2026'.encode()).hexdigest()
content=open('/home/ctf/cripto/hash/hash.txt').read().strip()
print('1' if h in content else '0')
" 2>/dev/null)
[ "$HASH_OK" = "1" ] && ok "MD5(MGP_Callao2026) correcto en hash.txt" || fail "Hash incorrecto"
grep -q "MGP_Callao2026" /home/ctf/cripto/hash/wordlist.txt && \
    ok "Wordlist contiene MGP_Callao2026" || fail "Wordlist sin contraseña"

echo ""
echo -e "${AMARILLO}── Reto 9: Vigenère ─────────────────────────────────${RESET}"
chk_file "mensaje.txt SSH"  "/home/ctf/cripto/vigenere/mensaje.txt"
chk_web  "Portal vigenere"  "http://localhost/cripto/vigenere/mensaje.txt"
VIG_OK=$(python3 -c "
import string
def dec(text,key):
    r='';key=key.upper();ki=0
    for c in text:
        if c.upper() in string.ascii_uppercase:
            s=ord(key[ki%len(key)])-ord('A')
            b=ord('A') if c.isupper() else ord('a')
            r+=chr((ord(c)-b-s)%26+b);ki+=1
        else: r+=c
    return r
content=open('/home/ctf/cripto/vigenere/mensaje.txt').read()
start=content.find('MENSAJE CIFRADO:')+len('MENSAJE CIFRADO:')
end=content.find('------',start)
cipher=content[start:end].strip()
result=dec(cipher,'MARINA')
print('1' if 'Comciberdef{vigenere_key_is_marina_2026}' in result else '0')
" 2>/dev/null)
[ "$VIG_OK" = "1" ] && ok "Vigenère descifra con clave MARINA" || fail "Vigenère no descifra"

echo ""
echo -e "${AMARILLO}── Reto 10: RSA Débil ───────────────────────────────${RESET}"
chk_file "public.pem SSH"      "/home/ctf/cripto/rsa/public.pem"
chk_file "mensaje.enc SSH"     "/home/ctf/cripto/rsa/mensaje.enc"
chk_file "mensaje.enc.hex SSH" "/home/ctf/cripto/rsa/mensaje.enc.hex"
chk_web  "Portal public.pem"   "http://localhost/cripto/rsa/public.pem"
chk_web  "Portal mensaje.enc"  "http://localhost/cripto/rsa/mensaje.enc"
chk_web  "Portal enc.hex"      "http://localhost/cripto/rsa/mensaje.enc.hex"
RSA_OK=$(python3 -c "
import math
from Crypto.PublicKey import RSA
from Crypto.Util.number import long_to_bytes
key=RSA.import_key(open('/home/ctf/cripto/rsa/public.pem').read())
n,e=key.n,key.e
c=int(open('/home/ctf/cripto/rsa/mensaje.enc.hex').read().strip(),16)
a=math.isqrt(n)+1; b2=a*a-n; b=math.isqrt(b2)
while b*b!=b2: a+=1; b2=a*a-n; b=math.isqrt(b2)
p,q=a-b,a+b
d=pow(e,-1,(p-1)*(q-1))
flag=long_to_bytes(pow(c,d,n)).decode()
print('1' if 'Comciberdef{rsa_fermat_2026}' in flag else '0')
" 2>/dev/null)
[ "$RSA_OK" = "1" ] && ok "RSA Fermat descifra flag" || fail "RSA Fermat falla"

echo ""
echo -e "${AMARILLO}── Portal Web ───────────────────────────────────────${RESET}"
chk_web "Portal /cripto/ índice" "http://localhost/cripto/"
# Verificar que el portal NO tiene README
grep -q "README" /var/www/html/cripto/index.html && \
    fail "Portal aun menciona README" || ok "Portal sin referencias a README"
# Verificar mensaje.enc en R10
grep -q "mensaje.enc\"" /var/www/html/cripto/index.html && \
    ok "Portal R10 muestra mensaje.enc" || fail "Portal R10 sin mensaje.enc"

# =============================================================================
# RESUMEN
# =============================================================================
echo ""
TOTAL=$((PASS+FAIL))
echo -e "${AZUL}${NEGRITA}══════════════════════════════════════════════════════════════${RESET}"
printf "${NEGRITA}  RESULTADO: %d/%d controles pasados\n${RESET}" "$PASS" "$TOTAL"
if [ "$FAIL" -eq 0 ]; then
    echo -e "${VERDE}${NEGRITA}  ✓ TODOS LOS RETOS CRIPTO DESPLEGADOS Y VERIFICADOS${RESET}"
else
    echo -e "${ROJO}${NEGRITA}  ✗ $FAIL controles fallaron${RESET}"
fi
echo -e "${AZUL}${NEGRITA}══════════════════════════════════════════════════════════════${RESET}"
echo ""
echo -e "${NEGRITA}  Acceso participantes:${RESET}"
echo "  WEB: http://192.168.125.150/cripto/"
echo "  SSH: /home/ctf/cripto/{cesar,base64,hash,vigenere,rsa}/"
echo ""
echo -e "${NEGRITA}  Flags:${RESET}"
echo "  R6  → Comciberdef{cesar_cipher_breaker_2026}"
echo "  R7  → Comciberdef{base64_multi_layer_decoded_2026}"
echo "  R8  → Comciberdef{MGP_Callao2026}"
echo "  R9  → Comciberdef{vigenere_key_is_marina_2026}"
echo "  R10 → Comciberdef{rsa_fermat_2026}"
echo -e "${AZUL}${NEGRITA}══════════════════════════════════════════════════════════════${RESET}"
