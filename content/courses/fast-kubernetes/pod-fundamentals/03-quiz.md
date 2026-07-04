---
kind: quiz
id_key: k8s/pod-fundamentals/quiz
course: fast-kubernetes
section: pod-fundamentals
section_title: Pod Fundamentals
section_position: 1
title: 'Quiz: Pod Fundamentals'
position: 2
estimated_minutes: 15
source: []
pass_percentage: 60
duration_minutes: 15
questions:
    - id_key: q1
      type: mcq
      difficulty: intermediate
      points: 2
      prompt: Which of the following best describes a Kubernetes Pod?
      multiple: false
      options:
          - text: A single container deployed directly on a host OS without any abstraction
            correct: false
          - text: The smallest deployable unit in Kubernetes; one or more tightly coupled containers sharing the same network namespace, IP address, and storage volumes
            correct: true
          - text: A logical grouping of worker nodes within a cluster
            correct: false
          - text: A configuration template that defines container images and restart policies
            correct: false
      explanation: |
          A Pod is Kubernetes' smallest deployable unit. All containers in a Pod share the same
          IP, port space, and localhost, and can share mounted volumes. Pods are ephemeral —
          they are not self-healing on their own; controllers like Deployments manage that.
    - id_key: q2
      type: mcq
      difficulty: intermediate
      points: 3
      prompt: In a multi-container Pod using the sidecar pattern (e.g. an nginx container plus a busybox helper), how do the two containers share files?
      multiple: false
      options:
          - text: They cannot share files; each container has a fully isolated filesystem
            correct: false
          - text: Through a shared volume (e.g. emptyDir) mounted into both containers' filesystems
            correct: true
          - text: Automatically, because containers in the same Pod always share the same filesystem root
            correct: false
          - text: Only via a NodePort Service exposing a shared path
            correct: false
      explanation: |
          Containers in a Pod share network and IPC namespaces but NOT filesystems by default —
          an explicit volume (commonly emptyDir for ephemeral sharing) must be declared and
          mounted into each container that needs access to the shared data.
    - id_key: q3
      type: coding
      difficulty: beginner
      points: 5
      prompt: |
          You receive a list of Pod statuses, one per line, in the form `NAME PHASE`. Count how
          many Pods are in the `Running` phase and print that count.

          **Example:**
          ```
          3
          web-1 Running
          web-2 Pending
          web-3 Running
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
                  if parts[1] == 'Running':
                      count += 1
              print(count)
          javascript: |
              const lines = require('fs').readFileSync(0, 'utf8').trim().split('\n');
              const n = parseInt(lines[0]);
              let count = 0;
              for (let i = 1; i <= n; i++) {
                const parts = lines[i].trim().split(/\s+/);
                if (parts[1] === 'Running') count++;
              }
              console.log(count);
      test_cases:
          - stdin: |
                3
                web-1 Running
                web-2 Pending
                web-3 Running
            expected: '2'
            hidden: false
            weight: 1
          - stdin: |
                1
                single-pod Running
            expected: '1'
            hidden: true
            weight: 1
          - stdin: |
                4
                a Pending
                b Pending
                c Running
                d Failed
            expected: '1'
            hidden: true
            weight: 1
---
