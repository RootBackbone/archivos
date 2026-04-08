#!/bin/bash
# =============================================================================
# CTF MGP — MIGRACIÓN DE FLAGS
# Cambia formato: Comciberdef{...} → CTF-MGP-2026[...]
# Afecta: MySQL, archivos PHP, Flask, archivos cripto, portal web
# Ejecutar: sudo bash migrate_flags.sh
# =============================================================================
set -e

VERDE="\e[32m"; AMARILLO="\e[33m"; ROJO="\e[31m"
AZUL="\e[34m"; NEGRITA="\e[1m"; RESET="\e[0m"

[ "$EUID" -ne 0 ] && { echo -e "${ROJO}Ejecutar como root: sudo bash $0${RESET}"; exit 1; }

echo -e "${AZUL}${NEGRITA}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║   CTF MGP — Migración de Flags                               ║"
echo "║   Comciberdef{...} → CTF-MGP-2026[...]                      ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${RESET}"

PASS=0; FAIL=0
ok()   { echo -e "  ${VERDE}[OK]${RESET}   $1"; PASS=$((PASS+1)); }
fail() { echo -e "  ${ROJO}[FAIL]${RESET} $1"; FAIL=$((FAIL+1)); }

# =============================================================================
# WEB — R1: MySQL sqli_db.users — contraseña del admin
# =============================================================================
echo -e "${AMARILLO}[WEB R1] SQL Injection — actualizando MySQL...${RESET}"
mysql -u root <<'SQLEOF'
USE sqli_db;
UPDATE users SET password='CTF-MGP-2026[sqli_bypass_2026_ok]'
WHERE username='admin';
SQLEOF
RESULT=$(mysql -u root -e "SELECT password FROM sqli_db.users WHERE username='admin';" -sN 2>/dev/null)
[ "$RESULT" = "CTF-MGP-2026[sqli_bypass_2026_ok]" ] && \
    ok "R1 MySQL actualizado: $RESULT" || fail "R1 MySQL no actualizado"

# =============================================================================
# WEB — R2: XSS — cookie en search.php
# =============================================================================
echo -e "${AMARILLO}[WEB R2] XSS — actualizando search.php...${RESET}"
for F in /var/www/html/xss/search.php; do
    sed -i 's/Comciberdef{xss_reflected_2026_found}/CTF-MGP-2026[xss_reflected_2026_found]/g' "$F"
done
grep -q "CTF-MGP-2026\[xss_reflected_2026_found\]" /var/www/html/xss/search.php && \
    ok "R2 search.php actualizado" || fail "R2 search.php no actualizado"

# =============================================================================
# WEB — R3: MySQL blind_db — hash de paco_admin
# El hash MD5 no cambia (es la contraseña NavalCiber2026 hasheada)
# La flag que el participante construye cambia de formato
# =============================================================================
echo -e "${AMARILLO}[WEB R3] SQLi Ciega — sin cambio en MySQL (hash MD5 permanece)${RESET}"
ok "R3 hash MD5 de NavalCiber2026 permanece igual — flag se construye con el texto crackeado"

# =============================================================================
# WEB — R4: LFI — /flag.txt
# =============================================================================
echo -e "${AMARILLO}[WEB R4] LFI — actualizando /flag.txt...${RESET}"
echo "CTF-MGP-2026[lfi_log_poison_rce_2026]" > /flag.txt
chmod 444 /flag.txt
chown root:root /flag.txt
RESULT=$(cat /flag.txt)
[ "$RESULT" = "CTF-MGP-2026[lfi_log_poison_rce_2026]" ] && \
    ok "R4 /flag.txt actualizado: $RESULT" || fail "R4 /flag.txt no actualizado"

# =============================================================================
# WEB — R5: SSRF — Flask storage_service.py
# =============================================================================
echo -e "${AMARILLO}[WEB R5] SSRF — actualizando storage_service.py y reiniciando...${RESET}"
sed -i 's/Comciberdef{ssrf_bypass_2026_master}/CTF-MGP-2026[ssrf_bypass_2026_master]/g' \
    /opt/ctf-ssrf/storage_service.py
grep -q "CTF-MGP-2026\[ssrf_bypass_2026_master\]" /opt/ctf-ssrf/storage_service.py && \
    ok "R5 storage_service.py actualizado" || fail "R5 storage_service.py no actualizado"
systemctl restart ctf-storage
sleep 2
ST=$(systemctl is-active ctf-storage 2>/dev/null || echo "inactive")
[ "$ST" = "active" ] && ok "R5 ctf-storage reiniciado" || fail "R5 ctf-storage no reinició"

# =============================================================================
# CRIPTO — R6: César shift=13 — re-cifrar con nueva flag
# =============================================================================
echo -e "${AMARILLO}[CRIPTO R6] César — re-cifrando mensaje.txt...${RESET}"
python3 -c "
import string
def enc(text, s):
    r=''
    for c in text:
        if c.upper() in string.ascii_uppercase:
            b=ord('A') if c.isupper() else ord('a')
            r+=chr((ord(c)-b+s)%26+b)
        else: r+=c
    return r

new_flag = 'CTF-MGP-2026[cesar_cipher_breaker_2026]'
plain = ('CLASIFICADO - NIVEL 1\n'
    'Servicio de Comunicaciones Navales - DIVCOMAR\n'
    'Origen: Base Naval del Callao | Fecha: 15-ENE-2026\n\n'
    '----------------------------------------------------------------------\n'
    'MENSAJE CIFRADO:\n\n'
    'Ln frthevqnq qr ynf pbzhavpnpvbarf aninyrf rf shaqnzragny.\n'
    'Ry bsvpvny n pnetb qror erpbeqne dhr yn pynir rf\n')

# El texto completo con la nueva flag cifrada
full_plain = ('La seguridad de las comunicaciones navales es fundamental. '
    'El oficial a cargo debe recordar que la clave de acceso es '
    + new_flag +
    ' y transmitirla solo por canales seguros.')

cipher_flag = enc(new_flag, 13)
full_cipher = enc(full_plain, 13)

content  = 'CLASIFICADO - NIVEL 1\n'
content += 'Servicio de Comunicaciones Navales - DIVCOMAR\n'
content += 'Origen: Base Naval del Callao | Fecha: 15-ENE-2026\n\n'
content += '----------------------------------------------------------------------\n'
content += 'MENSAJE CIFRADO:\n\n'
content += full_cipher + '\n\n'
content += '----------------------------------------------------------------------\n'

for path in ['/home/ctf/cripto/cesar/mensaje.txt',
             '/var/www/html/cripto/cesar/mensaje.txt']:
    open(path,'w').write(content)

# Verificar
def dec(text, s): return enc(text, 26-s)
assert new_flag in dec(full_cipher, 13), 'Error verificacion'
print(f'[OK] Cifrado: {full_cipher[:50]}...')
print(f'[OK] Flag en descifrado: {new_flag in dec(full_cipher,13)}')
" && ok "R6 mensaje.txt actualizado y verificado" || fail "R6 error en mensaje.txt"

# =============================================================================
# CRIPTO — R7: Base64 × 3 — re-codificar con nueva flag
# =============================================================================
echo -e "${AMARILLO}[CRIPTO R7] Base64 — re-codificando encoded.txt...${RESET}"
python3 -c "
import base64
flag = 'CTF-MGP-2026[base64_multi_layer_decoded_2026]'
l1 = base64.b64encode(flag.encode()).decode()
l2 = base64.b64encode(l1.encode()).decode()
l3 = base64.b64encode(l2.encode()).decode()

txt  = 'INTERCEPTADO - SISTEMA DE COMUNICACIONES MGP\n'
txt += '=============================================\n'
txt += 'Se ha capturado el siguiente dato codificado en transito.\n'
txt += 'Decodifique para obtener la informacion clasificada.\n\n'
txt += l3 + '\n'

for path in ['/home/ctf/cripto/base64/encoded.txt',
             '/var/www/html/cripto/base64/encoded.txt']:
    open(path,'w').write(txt)

# Verificar
d1=base64.b64decode(l3).decode()
d2=base64.b64decode(d1.strip()).decode()
d3=base64.b64decode(d2.strip()).decode()
assert d3==flag, f'Error: {d3}'
print(f'[OK] Verificado: {d3}')
" && ok "R7 encoded.txt actualizado y verificado" || fail "R7 error en encoded.txt"

# =============================================================================
# CRIPTO — R8: Hash — la contraseña crackeada sigue siendo MGP_Callao2026
# El hash MD5 no cambia. Solo la flag que construye el participante cambia formato.
# No hay nada que cambiar en el servidor para R8.
# =============================================================================
echo -e "${AMARILLO}[CRIPTO R8] Hash — sin cambio en servidor${RESET}"
ok "R8 hash MD5 permanece: 7a8f8d532e4a2229b0e843b02e962387 (MGP_Callao2026)"
ok "R8 participante construye: CTF-MGP-2026[MGP_Callao2026]"

# =============================================================================
# CRIPTO — R9: Vigenère clave MARINA — re-cifrar con nueva flag
# =============================================================================
echo -e "${AMARILLO}[CRIPTO R9] Vigenère — re-cifrando mensaje.txt...${RESET}"
python3 -c "
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
plain = ('El comando de ciberdefensa protege las redes navales del Pacifico Sur. '
         'Acceso nivel tres requerido. '
         'La contrasena de acceso al sistema clasificado es '
         'CTF-MGP-2026[vigenere_key_is_marina_2026]. '
         'Custodiar con maxima reserva. '
         'Solo el personal con clearance NIVEL-3 puede acceder a esta informacion.')
cipher = vig_enc(plain, key)
assert 'CTF-MGP-2026[vigenere_key_is_marina_2026]' in vig_dec(cipher, key)

content  = 'CLASIFICADO - NIVEL 3\n'
content += 'Servicio de Inteligencia Naval - DIRINA\n'
content += 'Origen: Base Naval del Callao | Ref: DIRINA-2026-0147\n'
content += '----------------------------------------------------------------------\n'
content += 'MENSAJE CIFRADO:\n'
content += cipher + '\n'
content += '----------------------------------------------------------------------\n'
content += 'Instrucciones:\n'
content += '  - Cifrado polialfabetico. La clave se repite a lo largo del mensaje.\n'

for path in ['/home/ctf/cripto/vigenere/mensaje.txt',
             '/var/www/html/cripto/vigenere/mensaje.txt']:
    open(path,'w',encoding='ascii').write(content)
print(f'[OK] Cifrado: {cipher[:60]}...')
print(f'[OK] Flag en descifrado: True')
" && ok "R9 mensaje.txt actualizado y verificado" || fail "R9 error en mensaje.txt"

# =============================================================================
# CRIPTO — R10: RSA — re-cifrar con nueva flag
# =============================================================================
echo -e "${AMARILLO}[CRIPTO R10] RSA — re-cifrando con nueva flag...${RESET}"
python3 -c "
import math
from Crypto.PublicKey import RSA
from Crypto.Util.number import long_to_bytes, bytes_to_long

p = 57896044618658097711785492504343953926634992332820282019728792003956564820063
q = 57896044618658097711785492504343953926634992332820282019728792003956564820243
n = p*q; e = 65537; d = pow(e,-1,(p-1)*(q-1))

new_flag = b'CTF-MGP-2026[rsa_fermat_2026]'
m = bytes_to_long(new_flag)
c = pow(m, e, n)
c_bytes = long_to_bytes(c)

# Guardar
import shutil
for base in ['/home/ctf/cripto/rsa', '/var/www/html/cripto/rsa']:
    open(f'{base}/mensaje.enc','wb').write(c_bytes)
    open(f'{base}/mensaje.enc.hex','w').write(c_bytes.hex()+'\n')

# Verificar con Fermat
a=math.isqrt(n)+1; b2=a*a-n; b=math.isqrt(b2)
while b*b!=b2: a+=1; b2=a*a-n; b=math.isqrt(b2)
p_f,q_f=a-b,a+b
d_f=pow(e,-1,(p_f-1)*(q_f-1))
dec=pow(c,d_f,n).to_bytes(len(new_flag),'big')
assert dec==new_flag, f'Error: {dec}'
print(f'[OK] Flag descifrada: {dec}')
print(f'[OK] c_hex: {c_bytes.hex()[:32]}...')
" && ok "R10 mensaje.enc + mensaje.enc.hex actualizados" || fail "R10 error RSA"

# =============================================================================
# PORTAL WEB /cripto/index.html — sin cambio de flags (portal no muestra flags)
# Solo actualizar instrucciones si mencionan Comciberdef
# =============================================================================
echo -e "${AMARILLO}[PORTAL] Verificando portal web...${RESET}"
grep -q "Comciberdef" /var/www/html/cripto/index.html 2>/dev/null && \
    fail "Portal /cripto/ menciona Comciberdef — revisar manualmente" || \
    ok "Portal /cripto/ limpio — no menciona flags"

# =============================================================================
# PHP WEB — verificar que no quedan referencias a Comciberdef en apps web
# =============================================================================
echo -e "${AMARILLO}[WEB] Verificando referencias restantes en apps PHP...${RESET}"
REMAIN=$(grep -r "Comciberdef" /var/www/html/ 2>/dev/null | grep -v ".bak" | wc -l)
[ "$REMAIN" -eq 0 ] && \
    ok "Sin referencias a Comciberdef en /var/www/html/" || \
    { fail "Quedan $REMAIN referencias — detalle:"; grep -r "Comciberdef" /var/www/html/ 2>/dev/null | grep -v ".bak" | head -10; }

# =============================================================================
# VALIDACIÓN FINAL RÁPIDA
# =============================================================================
echo ""
echo -e "${AZUL}${NEGRITA}══════════════════════════════════════════════════════════════${RESET}"
echo -e "${NEGRITA}  VALIDACIÓN RÁPIDA DE FLAGS${RESET}"
echo -e "${AZUL}${NEGRITA}══════════════════════════════════════════════════════════════${RESET}"

# R1 - SQLi bypass
B=$(curl -sL --data "username=%27+OR+1%3D1+LIMIT+4%2C1+--+-&password=x" \
    "http://localhost/sqli-login/" 2>/dev/null || echo "")
echo "$B" | grep -q "CTF-MGP-2026\[sqli_bypass_2026_ok\]" && \
    ok "R1 flag OK: CTF-MGP-2026[sqli_bypass_2026_ok]" || fail "R1 flag no encontrada"

# R2 - XSS cookie
H=$(curl -sI "http://localhost/xss/search.php?query=x" 2>/dev/null || echo "")
echo "$H" | grep -q "CTF-MGP-2026\[xss_reflected_2026_found\]" && \
    ok "R2 flag OK: CTF-MGP-2026[xss_reflected_2026_found]" || fail "R2 flag no encontrada"

# R4 - /flag.txt
[ "$(cat /flag.txt 2>/dev/null)" = "CTF-MGP-2026[lfi_log_poison_rce_2026]" ] && \
    ok "R4 flag OK: CTF-MGP-2026[lfi_log_poison_rce_2026]" || fail "R4 /flag.txt incorrecto"

# R5 - SSRF storage
TOKEN="MGP2026-IAM-xK9mN3pQ7rT1vY5wZ8"
F=$(curl -s -H "Authorization: Bearer $TOKEN" \
    "http://127.0.0.1:9999/secret/flag.txt" 2>/dev/null || echo "")
echo "$F" | grep -q "CTF-MGP-2026\[ssrf_bypass_2026_master\]" && \
    ok "R5 flag OK: CTF-MGP-2026[ssrf_bypass_2026_master]" || fail "R5 flag no encontrada"

# R6 - César
R6=$(python3 -c "
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
r=dec(txt,13)
print('1' if 'CTF-MGP-2026[cesar_cipher_breaker_2026]' in r else '0')
" 2>/dev/null)
[ "$R6" = "1" ] && ok "R6 flag OK: CTF-MGP-2026[cesar_cipher_breaker_2026]" || fail "R6 flag no encontrada"

# R7 - Base64
R7=$(python3 -c "
import base64
lines=open('/home/ctf/cripto/base64/encoded.txt').readlines()
for line in lines:
    line=line.strip()
    if line and ' ' not in line and len(line)>20:
        try:
            d1=base64.b64decode(line).decode()
            d2=base64.b64decode(d1.strip()).decode()
            d3=base64.b64decode(d2.strip()).decode()
            print('1' if 'CTF-MGP-2026[base64_multi_layer_decoded_2026]' in d3 else '0')
            break
        except: pass
" 2>/dev/null)
[ "$R7" = "1" ] && ok "R7 flag OK: CTF-MGP-2026[base64_multi_layer_decoded_2026]" || fail "R7 flag no encontrada"

# R9 - Vigenère
R9=$(python3 -c "
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
print('1' if 'CTF-MGP-2026[vigenere_key_is_marina_2026]' in result else '0')
" 2>/dev/null)
[ "$R9" = "1" ] && ok "R9 flag OK: CTF-MGP-2026[vigenere_key_is_marina_2026]" || fail "R9 flag no encontrada"

# R10 - RSA
R10=$(python3 -c "
import math
from Crypto.PublicKey import RSA
from Crypto.Util.number import long_to_bytes
key=RSA.import_key(open('/home/ctf/cripto/rsa/public.pem').read())
n,e=key.n,key.e
c=int(open('/home/ctf/cripto/rsa/mensaje.enc.hex').read().strip(),16)
a=math.isqrt(n)+1;b2=a*a-n;b=math.isqrt(b2)
while b*b!=b2: a+=1;b2=a*a-n;b=math.isqrt(b2)
p,q=a-b,a+b
d=pow(e,-1,(p-1)*(q-1))
flag=long_to_bytes(pow(c,d,n)).decode()
print('1' if 'CTF-MGP-2026[rsa_fermat_2026]' in flag else '0')
" 2>/dev/null)
[ "$R10" = "1" ] && ok "R10 flag OK: CTF-MGP-2026[rsa_fermat_2026]" || fail "R10 flag no encontrada"

# =============================================================================
# RESUMEN
# =============================================================================
echo ""
TOTAL=$((PASS+FAIL))
echo -e "${AZUL}${NEGRITA}══════════════════════════════════════════════════════════════${RESET}"
printf "${NEGRITA}  RESULTADO: %d/%d controles pasados\n${RESET}" "$PASS" "$TOTAL"
if [ "$FAIL" -eq 0 ]; then
    echo -e "${VERDE}${NEGRITA}  ✓ MIGRACIÓN COMPLETADA — Todas las flags en CTF-MGP-2026[...]${RESET}"
else
    echo -e "${ROJO}${NEGRITA}  ✗ $FAIL controles fallaron — revisar arriba${RESET}"
fi
echo -e "${AZUL}${NEGRITA}══════════════════════════════════════════════════════════════${RESET}"
echo ""
echo -e "${NEGRITA}  Nuevo formato de flags:${RESET}"
echo "  R1  → CTF-MGP-2026[sqli_bypass_2026_ok]"
echo "  R2  → CTF-MGP-2026[xss_reflected_2026_found]"
echo "  R3  → CTF-MGP-2026[NavalCiber2026]"
echo "  R4  → CTF-MGP-2026[lfi_log_poison_rce_2026]"
echo "  R5  → CTF-MGP-2026[ssrf_bypass_2026_master]"
echo "  R6  → CTF-MGP-2026[cesar_cipher_breaker_2026]"
echo "  R7  → CTF-MGP-2026[base64_multi_layer_decoded_2026]"
echo "  R8  → CTF-MGP-2026[MGP_Callao2026]"
echo "  R9  → CTF-MGP-2026[vigenere_key_is_marina_2026]"
echo "  R10 → CTF-MGP-2026[rsa_fermat_2026]"
echo -e "${AZUL}${NEGRITA}══════════════════════════════════════════════════════════════${RESET}"
