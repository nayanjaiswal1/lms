---
kind: lesson
id_key: docker/networking-volumes/networking
course: docker
section: networking-volumes
section_title: Networking & Storage
section_position: 5
title: "Container Networking: Bridge, Host, None and DNS"
position: 0
estimated_minutes: 10
source:
  - Docker Command Cheat Sheet.pdf
  - docker_cheatsheet.pdf (Red Hat CLI & Dockerfile cheat sheet)
---

## Why this matters

Real apps are several containers: an API, a database, a cache. They must find
each other by **name**, while the database stays hidden from the internet.
Docker networks give you exactly that, once you know which network type to use.

## Mental model: private office floors

Each **user-defined bridge network** is a private office floor. Containers on
the same floor can call each other by name (an internal phone book). Containers
on different floors cannot talk at all. The only way in from the street is a
published port (`-p`), a receptionist forwarding calls.

```
                host machine (the building)
   +---------------------------------------------------+
   |  network "shop" (floor 1)      network "admin"    |
   |  +-------+     +------+        +---------+        |
   |  |  api  |---->|  db  |        | grafana |        |
   |  +-------+     +------+        +---------+        |
   |      ^  "db" resolves via Docker's built-in DNS   |
   +------|--------------------------------------------+
          |  -p 8080:8000 (published port)
      the internet
```

## The network drivers

| Driver | What it is | Use it for |
|---|---|---|
| `bridge` (user-defined) | A private virtual network on one host, with **DNS by container name** | Almost everything on a single host |
| `bridge` (the default one, named `bridge`) | Where containers go if you pass no `--network`. **No DNS by name** | Quick one-off tests only |
| `host` | No network isolation: the container uses the host's network directly | Max performance, or tools that need the host's interfaces (Linux only) |
| `none` | No network at all (only loopback) | Batch jobs that must not talk to anything |
| `overlay` | A network spanning several hosts | Docker Swarm |
| `macvlan` / `ipvlan` | Container gets its own address on the physical LAN | Legacy apps that expect to be "a machine" on the network |

> **One-sentence rule.** Always create your own bridge network for containers
> that need to talk; the default bridge has no name resolution.

## See it work

```bash
# 1. Create a user-defined bridge network
docker network create shop

# 2. Start a "database" on it (nginx stands in for any server)
docker run -d --name db --network shop nginx:1.27-alpine

# 3. From another container on the same network, reach it BY NAME
docker run --rm --network shop busybox:1.36 wget -qO- http://db | head -n 4
```

Expected output: the first lines of the nginx welcome page HTML. The name `db`
was resolved by Docker's embedded DNS server (at `127.0.0.11` inside each container).

Now try from the default bridge:

```bash
docker run --rm busybox:1.36 wget -qO- -T 3 http://db
```

Expected: `wget: bad address 'db'`. Different network, and no DNS there anyway.

### Inspect and manage

```bash
docker network ls                      # bridge, host, none, shop
docker network inspect shop            # subnet, gateway, attached containers
docker network connect shop web        # attach a running container to another network
docker network disconnect shop web     # detach it
docker network rm shop                 # delete (no containers may be attached)
docker network prune                   # delete all unused networks
```

A container can be on **several** networks at once. That is how you build tiers:
the API joins both `frontend` and `backend`; the database joins only `backend`.

### Aliases

```bash
docker run -d --name pg-16 --network shop --network-alias database postgres:16
```

Other containers can now use `pg-16` or `database`.

### Ports, again

Containers on the same network talk on the **container** port directly
(`http://db:80`). You only need `-p` for traffic coming from **outside** Docker
(your browser, other machines). Do **not** publish your database port in
production unless something outside needs it.

## Try it

You run `api` and `postgres` with no `--network` flags. The API cannot connect to
`postgres:5432` ("could not translate host name"). Explain why and fix it.

<details>
<summary>Show answer</summary>

Both are on the **default** bridge, which has no DNS by container name. Fix:

```bash
docker network create app
docker network connect app postgres
docker network connect app api
```

(or recreate both with `--network app`). Now `postgres` resolves.

</details>

## Common mistakes

- **Relying on the default bridge** and container IPs. IPs change on restart;
  names on a user-defined network do not.
- **Using `localhost` to reach another container.** `localhost` inside a
  container is the container itself. Use the other container's name.
- **Publishing every port "just in case".** `-p 5432:5432` exposes your database
  to the network. Internal traffic does not need `-p`.
- **Expecting `--network host` on Docker Desktop to behave like Linux.** On
  macOS/Windows the "host" is Docker's VM; host networking support there is limited.

## Remember

- Create a **user-defined bridge** per app; containers on it resolve each other by name.
- The **default** bridge has no name-based DNS.
- `host` = share the host network; `none` = no network.
- `localhost` in a container means that container.
- `-p` is only for traffic from outside Docker.

**Self-check:**

1. Which network type gives you DNS by container name?
2. How do you put a container on two networks?
3. Does `api` need `-p` to reach `db` on the same network?
