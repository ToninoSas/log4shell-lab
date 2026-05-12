#!/usr/bin/env bash
# ================================================================
# compile.sh — Compila Exploit.java con target Java 8
# Eseguire dalla cartella payload/ oppure passare il path
# ================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$SCRIPT_DIR/Exploit.java"
OUT="$SCRIPT_DIR"

echo "[*] Compilazione Exploit.java → target Java 8"

# Rileva versione del compilatore
JAVA_VER=$(javac -version 2>&1 | awk '{print $2}' | cut -d. -f1)

if [ "$JAVA_VER" -ge 9 ] 2>/dev/null; then
    echo "[*] JDK $JAVA_VER rilevato → uso --release 8"
    javac --release 8 -d "$OUT" "$SRC"
else
    echo "[*] JDK 8 rilevato → compilazione standard"
    javac -d "$OUT" "$SRC"
fi

if [ $? -eq 0 ]; then
    echo "[+] Exploit.class generato in $OUT"
    echo "[+] Verifica bytecode:"
    javap -verbose "$OUT/Exploit.class" | grep "major version"
    # major version 52 = Java 8 ✓
else
    echo "[!] Compilazione fallita"
    exit 1
fi
