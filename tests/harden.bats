#!/usr/bin/env bats
# Pruebas de scripts/harden.sh con escenarios simulados.

load helpers

@test "sin opciones solo simula y no cambia nada" {
  preparar servidor-nuevo
  antes="$(huella)"
  ejecutar_script harden.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"Modo SIMULACIÓN"* ]]
  [[ "$output" == *"Lo marcado como [simulación] NO se ha cambiado."* ]]
  [[ "$output" != *"Cambios aplicados"* ]]
  [ "$(huella)" = "$antes" ]
  [ ! -s "$ESTADO/llamadas" ]
}

@test "--dry-run enseña la swap, fail2ban y el archivo de SSH que crearía" {
  preparar servidor-nuevo
  ejecutar_script harden.sh --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"[simulación] fallocate -l 2048M"* ]]
  [[ "$output" == *"apt-get"*"install -y -q fail2ban python3-systemd"* ]]
  [[ "$output" == *"| PasswordAuthentication no"* ]]
  [[ "$output" == *"| PermitRootLogin prohibit-password"* ]]
  [[ "$output" == *"[simulación] systemctl reload ssh"* ]]
}

@test "--dry-run sin sudo funciona y avisa de que no puede revisar las claves" {
  preparar servidor-nuevo 1000
  ejecutar_script harden.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"Sin sudo no puedo comprobar tus claves"* ]]
  [ ! -s "$ESTADO/llamadas" ]
}

@test "--dry-run no se combina con --apply" {
  preparar servidor-nuevo
  ejecutar_script harden.sh --dry-run --apply
  [ "$status" -eq 3 ]
}

@test "--swap-size rechaza tamaños sin unidad o fuera de rango" {
  preparar servidor-nuevo
  ejecutar_script harden.sh --swap-size 2
  [ "$status" -eq 3 ]
  ejecutar_script harden.sh --swap-size 64G
  [ "$status" -eq 3 ]
}

@test "--apply sin sudo se niega" {
  preparar servidor-nuevo 1000
  ejecutar_script harden.sh --apply
  [ "$status" -eq 1 ]
  [[ "$output" == *"hace falta sudo"* ]]
}

@test "--apply crea swap, fail2ban y actualizaciones, pero NO toca SSH" {
  preparar servidor-nuevo
  ejecutar_script harden.sh --apply
  [ "$status" -eq 0 ]
  grep -q '^fallocate -l 2048M' "$ESTADO/llamadas"
  grep -q '^swapon ' "$ESTADO/llamadas"
  grep -q '^/swapfile none swap sw 0 0$' "$FIXTURE/raiz/etc/fstab"
  grep -q '^vm.swappiness=10$' "$FIXTURE/raiz/etc/sysctl.d/99-vps-starter.conf"
  grep -q '^backend = systemd$' "$FIXTURE/raiz/etc/fail2ban/jail.d/vps-starter.local"
  grep -q 'Unattended-Upgrade "1"' "$FIXTURE/raiz/etc/apt/apt.conf.d/20auto-upgrades"
  [ ! -f "$FIXTURE/raiz/etc/ssh/sshd_config.d/00-hardening.conf" ]
  [[ "$output" == *"necesita reiniciarse"* ]]
}

@test "--apply dos veces: la segunda no cambia nada" {
  preparar servidor-nuevo
  ejecutar_script harden.sh --apply
  [ "$status" -eq 0 ]
  : >"$ESTADO/llamadas"
  antes="$(huella)"
  ejecutar_script harden.sh --apply
  [ "$status" -eq 0 ]
  [[ "$output" != *"Cambios aplicados"* ]]
  [[ "$output" != *"→"* ]]
  [ "$(huella)" = "$antes" ]
  [ ! -s "$ESTADO/llamadas" ]
}

@test "sin disco suficiente no crea la swap" {
  preparar servidor-nuevo
  sed -i 's/ 27343 / 1500 /' "$ESTADO/df_m"
  ejecutar_script harden.sh --apply
  [ "$status" -eq 0 ]
  [[ "$output" == *"No hay disco suficiente"* ]]
  no_aparece '^fallocate' "$ESTADO/llamadas"
  [ ! -f "$FIXTURE/raiz/swapfile" ]
}

@test "si ya hay swap, no crea otra" {
  preparar servidor-nuevo
  echo "/swap.img file 1G 0B -2" >"$ESTADO/swap"
  ejecutar_script harden.sh --apply
  [[ "$output" == *"Ya hay swap activa; no se toca."* ]]
  no_aparece '^fallocate' "$ESTADO/llamadas"
  no_aparece 'swapfile' "$FIXTURE/raiz/etc/fstab"
}

@test "--apply-ssh sin claves autorizadas se niega y no toca nada" {
  preparar servidor-nuevo
  rm "$FIXTURE/raiz/root/.ssh/authorized_keys"
  ejecutar_script harden.sh --apply-ssh
  [ "$status" -eq 1 ]
  [[ "$output" == *"te quedarías fuera"* ]]
  [ ! -f "$FIXTURE/raiz/etc/ssh/sshd_config.d/00-hardening.conf" ]
}

@test "--apply-ssh con clave escribe el archivo, valida y recarga SSH" {
  preparar servidor-nuevo
  echo ssh >>"$ESTADO/activos"
  ejecutar_script harden.sh --apply-ssh
  [ "$status" -eq 0 ]
  conf="$FIXTURE/raiz/etc/ssh/sshd_config.d/00-hardening.conf"
  grep -qx 'PasswordAuthentication no' "$conf"
  grep -qx 'KbdInteractiveAuthentication no' "$conf"
  grep -qx 'PermitRootLogin prohibit-password' "$conf"
  grep -qx 'sshd -t' "$ESTADO/llamadas"
  grep -qx 'systemctl reload ssh' "$ESTADO/llamadas"
  [[ "$output" == *"no cierres esta sesión"* ]]
  # --apply-ssh solo toca SSH
  no_aparece '^fallocate' "$ESTADO/llamadas"
}

@test "--apply-ssh con sudo desde otro usuario mira las claves de ese usuario" {
  preparar servidor-nuevo
  # root tiene clave, pero quien usa sudo es "ana", que no tiene ninguna.
  mkdir -p "$FIXTURE/raiz/home/ana/.ssh"
  run "$BIN/env" -i PATH="$BIN" VPS_ROOT="$FIXTURE/raiz" ESTADO="$ESTADO" NO_COLOR=1 SUDO_USER=ana \
    "$BIN/bash" "$RAIZ_REPO/scripts/harden.sh" --apply-ssh
  [ "$status" -eq 1 ]
  [[ "$output" == *"El usuario 'ana' no tiene ninguna clave"* ]]
  [ ! -f "$FIXTURE/raiz/etc/ssh/sshd_config.d/00-hardening.conf" ]
}

@test "--apply-ssh deshace el cambio si la configuración no es válida" {
  preparar servidor-nuevo
  touch "$ESTADO/sshd_t_falla"
  ejecutar_script harden.sh --apply-ssh
  [ "$status" -eq 1 ]
  [[ "$output" == *"no es válida. La deshago."* ]]
  [ ! -f "$FIXTURE/raiz/etc/ssh/sshd_config.d/00-hardening.conf" ]
  no_aparece 'reload' "$ESTADO/llamadas"
}

@test "--apply-ssh dos veces: la segunda no recarga SSH" {
  preparar servidor-nuevo
  echo ssh >>"$ESTADO/activos"
  ejecutar_script harden.sh --apply-ssh
  : >"$ESTADO/llamadas"
  ejecutar_script harden.sh --apply-ssh
  [ "$status" -eq 0 ]
  [[ "$output" == *"00-hardening.conf ya estaba bien."* ]]
  [ ! -s "$ESTADO/llamadas" ]
}
