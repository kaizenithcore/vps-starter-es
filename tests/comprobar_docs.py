#!/usr/bin/env python3
"""Comprueba las guías de vps-starter-es.

- Cada guía de docs/ (las que empiezan por número) tiene el front matter
  completo y las secciones de la plantilla.
- Todos los enlaces internos (archivo y ancla) existen, también los que
  cita scripts/check.sh.
- No hay direcciones IP reales en documentación ni scripts.

Uso: python3 tests/comprobar_docs.py   (desde la raíz del repositorio)
Sale con código 1 y una lista de errores si algo no cuadra.
"""

import re
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
CLAVES = ["id", "objetivo", "riesgo", "requiere_confirmacion_humana",
          "tiempo_estimado", "requisitos", "verificacion", "reversion"]
SECCIONES = ["## Antes de empezar", "## Pasos", "## Cómo saber que ha ido bien",
             "## Si algo falla", "## Cómo deshacerlo"]
IPS_PERMITIDAS = re.compile(r"^(0\.0\.0\.0|127\.|10\.|172\.(1[6-9]|2\d|3[01])\.|192\.168\.)")
# Números de versión que parecen IPs (por ejemplo 3.0.13.0) se evitan pidiendo
# que no vayan pegados a letras, guiones o puntos.
RE_IP = re.compile(r"(?<![\w.\-])(\d{1,3}(?:\.\d{1,3}){3})(?![\w.\-])")

errores = []


def error(archivo, mensaje):
    errores.append(f"{archivo.relative_to(RAIZ)}: {mensaje}")


def slug(titulo):
    """Ancla que GitHub genera para un título (conserva tildes y ñ)."""
    t = titulo.strip().lower()
    t = re.sub(r"[^\w\- ]", "", t)
    return t.replace(" ", "-")


def anclas(archivo):
    resultado, vistos, en_codigo = set(), {}, False
    for linea in archivo.read_text(encoding="utf-8").splitlines():
        if linea.startswith("```"):
            en_codigo = not en_codigo
            continue
        m = re.match(r"^#{1,6}\s+(.*)$", linea)
        if m and not en_codigo:
            base = slug(m.group(1))
            n = vistos.get(base, 0)
            resultado.add(base if n == 0 else f"{base}-{n}")
            vistos[base] = n + 1
    return resultado


def front_matter(archivo, texto):
    if not texto.startswith("---\n"):
        error(archivo, "no empieza con front matter (---)")
        return {}
    fin = texto.find("\n---\n", 4)
    if fin == -1:
        error(archivo, "el front matter no se cierra con ---")
        return {}
    datos = {}
    for linea in texto[4:fin].splitlines():
        if ":" in linea:
            clave, valor = linea.split(":", 1)
            valor = valor.split(" #")[0].strip().strip('"')
            datos[clave.strip()] = valor
    return datos


def comprobar_guia(archivo):
    texto = archivo.read_text(encoding="utf-8")
    datos = front_matter(archivo, texto)
    for clave in CLAVES:
        if not datos.get(clave):
            error(archivo, f"falta '{clave}' en el front matter")
    if datos.get("id") and datos["id"] != archivo.stem:
        error(archivo, f"id '{datos['id']}' no coincide con el nombre del archivo")
    if datos.get("riesgo") and datos["riesgo"] not in ("bajo", "medio", "alto"):
        error(archivo, f"riesgo '{datos['riesgo']}' no es bajo, medio ni alto")
    if datos.get("requiere_confirmacion_humana") not in (None, "true", "false"):
        error(archivo, "requiere_confirmacion_humana debe ser true o false")
    requisitos = datos.get("requisitos", "")
    if requisitos and not (requisitos.startswith("[") and requisitos.endswith("]")):
        error(archivo, "requisitos debe ser una lista entre corchetes")
    for req in filter(None, (r.strip() for r in requisitos.strip("[]").split(","))):
        if not (RAIZ / "docs" / f"{req}.md").exists():
            error(archivo, f"requisito '{req}' no es una guía existente")
    reversion = datos.get("reversion", "")
    if reversion.startswith("#") and reversion[1:] not in anclas(archivo):
        error(archivo, f"reversion apunta a '{reversion}', que no existe")
    if not re.search(r"^# \S", texto, re.M):
        error(archivo, "falta el título (# ...)")
    if "**En una frase:**" not in texto:
        error(archivo, "falta '**En una frase:**'")
    posicion = -1
    for seccion in SECCIONES:
        p = texto.find(f"\n{seccion}\n")
        if p == -1:
            error(archivo, f"falta la sección '{seccion}'")
        elif p < posicion:
            error(archivo, f"la sección '{seccion}' está fuera de orden")
        else:
            posicion = p
    if datos.get("requiere_confirmacion_humana") == "true" and datos.get("riesgo") in ("medio", "alto"):
        if "**ALTO: necesita confirmación humana.**" not in texto:
            error(archivo, "riesgo medio/alto sin ningún punto de parada ALTO")


def comprobar_enlace(archivo, destino):
    if re.match(r"^[a-z]+:", destino):
        return  # enlace externo
    ruta, _, ancla = destino.partition("#")
    objetivo = (archivo.parent / ruta).resolve() if ruta else archivo
    if not objetivo.exists():
        error(archivo, f"enlace roto: {destino}")
        return
    if ancla and objetivo.suffix == ".md" and ancla not in anclas(objetivo):
        error(archivo, f"ancla inexistente: {destino}")


def comprobar_enlaces_markdown(archivo):
    en_codigo = False
    for linea in archivo.read_text(encoding="utf-8").splitlines():
        if linea.startswith("```"):
            en_codigo = not en_codigo
            continue
        if en_codigo:
            continue
        for destino in re.findall(r"\]\(([^)\s]+)\)", linea):
            comprobar_enlace(archivo, destino)


def comprobar_enlaces_check_sh():
    archivo = RAIZ / "scripts" / "check.sh"
    texto = archivo.read_text(encoding="utf-8")
    guias = dict(re.findall(r'^(GUIA_\w+)="([^"]+)"', texto, re.M))
    for var, ruta in guias.items():
        if not (RAIZ / ruta).exists():
            error(archivo, f"{var} apunta a {ruta}, que no existe")
    for var, ancla in re.findall(r'\$(GUIA_\w+)#([^"\s]+)', texto):
        ruta = guias.get(var)
        if ruta and (RAIZ / ruta).exists() and ancla not in anclas(RAIZ / ruta):
            error(archivo, f"ancla inexistente: {ruta}#{ancla}")


def comprobar_ips(archivo):
    for n, linea in enumerate(archivo.read_text(encoding="utf-8").splitlines(), 1):
        for ip in RE_IP.findall(linea):
            if not IPS_PERMITIDAS.match(ip):
                error(archivo, f"línea {n}: posible IP real '{ip}'")


def main():
    guias = sorted((RAIZ / "docs").glob("[0-9][0-9]-*.md"))
    if not guias:
        error(RAIZ / "docs", "no hay guías")
    for guia in guias:
        comprobar_guia(guia)
    markdown = [p for p in RAIZ.rglob("*.md")
                if ".git" not in p.parts and "fixtures" not in p.parts
                and not p.name.lower().startswith("plan")]
    for archivo in markdown:
        comprobar_enlaces_markdown(archivo)
    comprobar_enlaces_check_sh()
    for archivo in markdown + sorted((RAIZ / "scripts").rglob("*.sh")) + [RAIZ / "llms.txt"]:
        comprobar_ips(archivo)

    if errores:
        print("\n".join(errores))
        print(f"\n{len(errores)} problema(s).")
        return 1
    print(f"Documentación correcta: {len(guias)} guías, {len(markdown)} archivos Markdown revisados.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
