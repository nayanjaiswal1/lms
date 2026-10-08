export interface DemoContainer {
  id: string;
  name: string;
  image: string;
  ports: string[];
  running: boolean;
}

export interface DockerState {
  containers: DemoContainer[];
  readLogs: boolean;
  nextId: number;
}

export interface CommandResult {
  state: DockerState;
  output: string;
}

export const INITIAL_DOCKER_STATE: DockerState = { containers: [], readLogs: false, nextId: 1 };

const KNOWN_IMAGES = ["nginx", "redis", "postgres", "alpine", "busybox"];

const HELP = [
  "Commands: docker ps [-a] · docker images · docker run [-d] [--name N] [-p H:C] IMAGE",
  "          docker stop N · docker rm N · docker logs N · clear",
].join("\n");

function fakeId(n: number): string {
  return (n * 2654435761 >>> 0).toString(16).padStart(8, "0").repeat(2).slice(0, 12);
}

function table(rows: string[][]): string {
  const widths = rows[0].map((_, c) => Math.max(...rows.map((r) => r[c].length)));
  return rows.map((r) => r.map((cell, c) => cell.padEnd(widths[c] + 2)).join("").trimEnd()).join("\n");
}

function run(state: DockerState, args: string[]): CommandResult {
  let detached = false;
  let name = "";
  const ports: string[] = [];
  let image = "";

  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    if (a === "-d") detached = true;
    else if (a === "--name") name = args[++i] ?? "";
    else if (a === "-p") ports.push(args[++i] ?? "");
    else if (a.startsWith("-")) return { state, output: `unknown flag: ${a}` };
    else { image = a; break; }
  }

  if (!image) return { state, output: "docker: 'docker run' requires an image." };
  const base = image.split(":")[0];
  if (!KNOWN_IMAGES.includes(base)) {
    return { state, output: `Unable to find image '${image}' locally\ndocker: pull access denied for ${base}, repository does not exist.` };
  }
  if (ports.some((p) => !/^\d+:\d+$/.test(p))) return { state, output: "invalid port mapping, use HOST:CONTAINER (e.g. 8080:80)" };

  const finalName = name || `container_${state.nextId}`;
  if (state.containers.some((c) => c.name === finalName)) {
    return { state, output: `docker: Conflict. The container name "/${finalName}" is already in use.` };
  }

  const container: DemoContainer = { id: fakeId(state.nextId), name: finalName, image, ports, running: true };
  return {
    state: { ...state, containers: [...state.containers, container], nextId: state.nextId + 1 },
    output: detached ? container.id : `Started ${finalName} (use -d to run in the background)`,
  };
}

function find(state: DockerState, target: string | undefined): DemoContainer | undefined {
  return state.containers.find((c) => c.name === target || c.id.startsWith(target ?? "\0"));
}

export function runDockerCommand(state: DockerState, line: string): CommandResult {
  const parts = line.trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return { state, output: "" };
  if (parts[0] === "help") return { state, output: HELP };
  if (parts[0] !== "docker") return { state, output: `${parts[0]}: command not found (try: help)` };

  const [, sub, ...rest] = parts;
  switch (sub) {
    case "ps": {
      const all = rest.includes("-a");
      const rows = state.containers.filter((c) => all || c.running);
      return {
        state,
        output: table([
          ["CONTAINER ID", "IMAGE", "STATUS", "PORTS", "NAMES"],
          ...rows.map((c) => [c.id, c.image, c.running ? "Up 5 seconds" : "Exited (0)", c.ports.map((p) => p.replace(":", "->") + "/tcp").join(", "), c.name]),
        ]),
      };
    }
    case "images":
      return { state, output: table([["REPOSITORY", "TAG", "SIZE"], ...KNOWN_IMAGES.map((i) => [i, "latest", "~60MB"])]) };
    case "run":
      return run(state, rest);
    case "stop": {
      const c = find(state, rest[0]);
      if (!c) return { state, output: `Error: No such container: ${rest[0] ?? ""}` };
      return { state: { ...state, containers: state.containers.map((x) => (x === c ? { ...x, running: false } : x)) }, output: c.name };
    }
    case "rm": {
      const c = find(state, rest[0]);
      if (!c) return { state, output: `Error: No such container: ${rest[0] ?? ""}` };
      if (c.running) return { state, output: `Error: cannot remove running container ${c.name}; stop it first` };
      return { state: { ...state, containers: state.containers.filter((x) => x !== c) }, output: c.name };
    }
    case "logs": {
      const c = find(state, rest[0]);
      if (!c) return { state, output: `Error: No such container: ${rest[0] ?? ""}` };
      return {
        state: { ...state, readLogs: true },
        output: `/docker-entrypoint.sh: Configuration complete; ready for start up\n${c.image}: ready for connections`,
      };
    }
    default:
      return { state, output: `docker: '${sub ?? ""}' is not supported in this demo (try: help)` };
  }
}

// One predicate per task id, evaluated against the current container state.
export function dockerTasksPassed(state: DockerState): Set<string> {
  const passed = new Set<string>();
  const web = state.containers.find((c) => c.name === "web" && c.running && c.image.split(":")[0] === "nginx");
  if (web) passed.add("t1");
  if (web?.ports.includes("8080:80")) passed.add("t2");
  if (state.readLogs && web) passed.add("t3");
  return passed;
}
