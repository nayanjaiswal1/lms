# Boots WSL2 (and its systemd -> k3s, already `systemctl enable`d) after a
# Windows restart/logon, then force-restarts any pod stuck in "Unknown" —
# the state traefik/piston have both landed in after WSL2 resumes, which a
# plain `wsl.exe` boot alone doesn't clear.
# Registered as a Task Scheduler "At log on" action — see docs/local-k3s-dev.md.

$distro = "Ubuntu-22.04"

wsl.exe -d $distro -e true

wsl.exe -d $distro -e bash -c @'
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=traefik -n kube-system --timeout=90s 2>/dev/null \
  || kubectl delete pod -n kube-system -l app.kubernetes.io/name=traefik --force --grace-period=0

kubectl get deploy backend -n mindforge -o jsonpath="{.spec.replicas}" | grep -qv "^0$" \
  || kubectl scale deployment/backend -n mindforge --replicas=2
'@
