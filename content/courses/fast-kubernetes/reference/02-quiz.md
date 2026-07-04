---
kind: quiz
id_key: k8s/reference/quiz
course: fast-kubernetes
section: reference
section_title: Reference
section_position: 10
title: 'Quiz: kubectl Command Reference'
position: 1
estimated_minutes: 15
source: []
pass_percentage: 60
duration_minutes: 15
questions:
    - id_key: q1
      type: mcq
      difficulty: beginner
      points: 2
      prompt: Which flag lists Pods across every namespace instead of just the current one?
      multiple: false
      options:
          - text: kubectl get pods -o wide
            correct: false
          - text: kubectl get pods -A (or --all-namespaces)
            correct: true
          - text: kubectl get pods -w
            correct: false
          - text: kubectl get pods -n default
            correct: false
      explanation: |
          -A / --all-namespaces lists Pods across every namespace. -n <namespace> restricts output
          to a single namespace (default is the "default" namespace if omitted). -o wide adds extra
          columns (like node and IP) but stays scoped to the current namespace. -w watches for
          changes to the resources in the current namespace scope.
    - id_key: q2
      type: mcq
      difficulty: intermediate
      points: 3
      prompt: 'You need an interactive shell inside a Pod named `multicontainer` that has two containers, `webcontainer` and `sidecarcontainer`. Which command opens a shell specifically in `sidecarcontainer`?'
      multiple: false
      options:
          - text: kubectl exec -it multicontainer -- /bin/sh
            correct: false
          - text: kubectl exec -it multicontainer -c sidecarcontainer -- /bin/sh
            correct: true
          - text: kubectl logs -f multicontainer -c sidecarcontainer
            correct: false
          - text: kubectl port-forward pod/multicontainer -c sidecarcontainer
            correct: false
      explanation: |
          The -c <containerName> flag selects which container to target when a Pod runs more than
          one container. Without -c, kubectl exec defaults to the Pod's first container. kubectl
          logs -f -c streams logs rather than opening a shell, and port-forward does not accept a
          -c flag at all.
    - id_key: q3
      type: coding
      difficulty: intermediate
      points: 5
      prompt: |
          You receive a simplified `kubectl get pods -A` listing, one Pod per line, in the form
          `NAMESPACE NAME PHASE`. Count how many Pods are NOT in the `kube-system` namespace and
          print that count.

          **Example:**
          ```
          4
          kube-system coredns-1 Running
          default web-1 Running
          default web-2 Pending
          kube-system etcd-1 Running
          ```
          Output: `2`
      languages:
          - python
          - javascript
      starter_code:
          python: |
              import sys
              lines = sys.stdin.read().split('\n')
              n = int(lines[0])
              count = 0
              for i in range(1, n + 1):
                  parts = lines[i].split()
                  if parts[0] != 'kube-system':
                      count += 1
              print(count)
          javascript: |
              const lines = require('fs').readFileSync(0, 'utf8').trim().split('\n');
              const n = parseInt(lines[0]);
              let count = 0;
              for (let i = 1; i <= n; i++) {
                const parts = lines[i].trim().split(/\s+/);
                if (parts[0] !== 'kube-system') count++;
              }
              console.log(count);
      test_cases:
          - stdin: |
                4
                kube-system coredns-1 Running
                default web-1 Running
                default web-2 Pending
                kube-system etcd-1 Running
            expected: '2'
            hidden: false
            weight: 1
          - stdin: |
                1
                default single-pod Running
            expected: '1'
            hidden: true
            weight: 1
          - stdin: |
                5
                kube-system a Running
                kube-system b Running
                kube-system c Running
                production d Running
                production e Pending
            expected: '2'
            hidden: true
            weight: 1
---
