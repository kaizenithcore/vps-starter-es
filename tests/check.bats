#!/usr/bin/env bats
# Pruebas de scripts/check.sh con escenarios simulados.

load helpers

@test "servidor nuevo: detecta SSH con contraseña y root con contraseña" {
  preparar servidor-nuevo
  ejecutar_script check.sh
  [ "$status" -eq 2 ]
  [[ "$output" == *"[FALLO]  SSH acepta contraseñas."* ]]
  [[ "$output" == *"[FALLO]  El usuario root puede entrar con contraseña."* ]]
}

@test "servidor nuevo: avisa de swap, memoria agotada, actualizaciones y reinicio" {
  preparar servidor-nuevo
  ejecutar_script check.sh
  [[ "$output" == *"[AVISO]  No hay memoria de intercambio (swap)."* ]]
  [[ "$output" == *"(2 avisos en el registro)"* ]]
  [[ "$output" == *"Hay 3 actualizaciones pendientes (2 de seguridad)"* ]]
  [[ "$output" == *"necesita reiniciarse"* ]]
  [[ "$output" == *"fail2ban no está activo"* ]]
}

@test "servidor nuevo: detecta el panel de Coolify parado y el puerto 8080 abierto" {
  preparar servidor-nuevo
  ejecutar_script check.sh
  [[ "$output" == *"[FALLO]  Coolify está instalado pero su panel está parado."* ]]
  [[ "$output" == *"El puerto 8080 escucha hacia Internet."* ]]
  [[ "$output" != *"puerto 8000"* ]]
  [[ "$output" != *"5432"* ]]
  [[ "$output" == *"Contenedores parados: coolify coolify-db coolify-redis coolify-realtime."* ]]
}

@test "servidor protegido: sin ningún FALLO" {
  preparar servidor-protegido
  ejecutar_script check.sh
  [ "$status" -eq 1 ]
  [[ "$output" != *"[FALLO]"* ]]
  [[ "$output" == *"[OK]     SSH no acepta contraseñas: solo se entra con clave."* ]]
  [[ "$output" == *"[OK]     El usuario root solo puede entrar con clave."* ]]
  [[ "$output" == *"Docker no está instalado."* ]]
  [[ "$output" == *"Solo escuchan hacia Internet los puertos TCP esperados: 22, 80, 443."* ]]
}

@test "el firewall de Hostinger siempre sale como AVISO" {
  preparar servidor-protegido
  ejecutar_script check.sh --section firewall
  [ "$status" -eq 1 ]
  [[ "$output" == *"[AVISO]  El firewall de Hostinger no se ve desde dentro"* ]]
}

@test "--json devuelve un resumen legible por máquina" {
  preparar servidor-nuevo
  ejecutar_script check.sh --json
  [ "$status" -eq 2 ]
  [[ "$output" == '{"resumen":{"ok":'* ]]
  [[ "$output" == *'"estado":"FALLO"'* ]]
  if command -v jq >/dev/null; then
    echo "$output" | jq -e '.resumen.fallo > 0 and (.comprobaciones | length) > 5'
  fi
}

@test "--section limita la revisión a esa parte" {
  preparar servidor-nuevo
  ejecutar_script check.sh --section ssh
  [[ "$output" == *"Acceso por SSH"* ]]
  [[ "$output" != *"Memoria"* ]]
  [[ "$output" != *"Puertos abiertos"* ]]
}

@test "--section con varias partes separadas por comas" {
  preparar servidor-protegido
  ejecutar_script check.sh --section disco,sistema
  [ "$status" -eq 0 ]
  [[ "$output" == *"Disco al 45 %"* ]]
  [[ "$output" == *"Ubuntu 24.04"* ]]
}

@test "--section desconocida es un error de uso" {
  preparar servidor-nuevo
  ejecutar_script check.sh --section inventada
  [ "$status" -eq 3 ]
  [[ "$output" == *"Parte desconocida: inventada"* ]]
}

@test "sin sudo no revisa SSH ni Docker, y lo dice" {
  preparar servidor-nuevo 1000
  ejecutar_script check.sh --section ssh
  [[ "$output" == *"Para revisar SSH hace falta sudo"* ]]
  [[ "$output" != *"[FALLO]"* ]]
}

@test "disco casi lleno da FALLO" {
  preparar servidor-protegido
  sed -i 's/ 45% / 93% /' "$ESTADO/df_k"
  ejecutar_script check.sh --section disco
  [ "$status" -eq 2 ]
  [[ "$output" == *"[FALLO]  El disco está al 93 %"* ]]
}

@test "check.sh no cambia nada ni llama a comandos que modifiquen el sistema" {
  preparar servidor-nuevo
  antes="$(huella)"
  ejecutar_script check.sh
  [ "$(huella)" = "$antes" ]
  [ -z "$(grep -Ev '^sshd -T$' "$ESTADO/llamadas")" ]
}

@test "ignora puertos que solo escuchan en redes privadas" {
  preparar servidor-nuevo
  ejecutar_script check.sh --section puertos
  [[ "$output" != *"puerto 53 "* ]]
  [[ "$output" != *"9000"* ]]
}

@test "si sshd -T falla, lee los archivos de SSH (gana el primer valor)" {
  preparar servidor-nuevo
  rm "$ESTADO/sshd_T"
  ejecutar_script check.sh --section ssh
  [[ "$output" == *"[FALLO]  SSH acepta contraseñas."* ]]
  [[ "$output" == *"[FALLO]  El usuario root puede entrar con contraseña."* ]]

  # 00-hardening.conf va antes que 50-cloud-init.conf: sus valores ganan.
  printf 'PasswordAuthentication no\nKbdInteractiveAuthentication no\nPermitRootLogin prohibit-password\n' \
    >"$FIXTURE/raiz/etc/ssh/sshd_config.d/00-hardening.conf"
  ejecutar_script check.sh --section ssh
  [[ "$output" == *"[OK]     SSH no acepta contraseñas: solo se entra con clave."* ]]
  [[ "$output" == *"[OK]     El usuario root solo puede entrar con clave."* ]]
}
