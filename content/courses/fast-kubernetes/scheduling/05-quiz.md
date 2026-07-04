---
kind: quiz
id_key: k8s/scheduling/quiz
course: fast-kubernetes
section: scheduling
section_title: Health & Scheduling
section_position: 6
title: 'Quiz: Health & Scheduling'
position: 4
estimated_minutes: 15
source: []
pass_percentage: 60
duration_minutes: 15
questions:
    - id_key: q1
      type: mcq
      difficulty: intermediate
      points: 2
      prompt: In the lesson's liveness-exec Pod, the container runs `touch /tmp/healthy; sleep 30; rm -rf /tmp/healthy; sleep 600`, and its livenessProbe runs `cat /tmp/healthy` every 5 seconds after an initial 5 second delay. What happens roughly 30+ seconds after the container starts?
      multiple: false
      options:
          - text: Nothing happens; the probe only runs once at container startup
            correct: false
          - text: The probe starts failing because the file no longer exists, and kubelet restarts the container
            correct: true
          - text: The Pod is immediately deleted by the scheduler
            correct: false
          - text: The probe passes forever because the file existed at some point during the container's life
            correct: false
      explanation: |
          Once /tmp/healthy is removed at around 30 seconds, each subsequent `cat /tmp/healthy`
          liveness check (run every periodSeconds: 5) returns a non-zero exit code, so the probe
          reports failure. Kubelet responds by restarting the container — this is exactly what a
          liveness probe is for: detecting a stuck or unhealthy process and recovering from it.
    - id_key: q2
      type: mcq
      difficulty: intermediate
      points: 3
      prompt: In the lesson's node affinity lab, before any node is labelled app=production, nodeaffinitypod1 (which uses requiredDuringSchedulingIgnoredDuringExecution for the app=production label) and nodeaffinitypod2 (which uses preferredDuringSchedulingIgnoredDuringExecution for the same label) are both created. What is the observed result?
      multiple: false
      options:
          - text: Both pods start running immediately on any available node
            correct: false
          - text: nodeaffinitypod1 stays Pending until a node is labelled app=production, while nodeaffinitypod2 starts running immediately anyway
            correct: true
          - text: Both pods stay Pending forever because no node has the app=production label
            correct: false
          - text: nodeaffinitypod2 stays Pending while nodeaffinitypod1 runs immediately, the reverse of what actually happens
            correct: false
      explanation: |
          requiredDuringSchedulingIgnoredDuringExecution is a hard requirement — the pod will not
          be scheduled until a matching node exists, so nodeaffinitypod1 stays Pending.
          preferredDuringSchedulingIgnoredDuringExecution is only a soft preference — the
          scheduler tries to honor it but still runs the pod anywhere if no matching node is
          found, so nodeaffinitypod2 starts immediately. Once the node is labelled
          app=production, the required pod also starts running.
    - id_key: q3
      type: coding
      difficulty: intermediate
      points: 5
      prompt: |
          You are given a node's taint and a Pod's list of tolerations, and must decide whether
          the Pod can be scheduled on the node.

          **Input:**
          - Line 1: the taint in the form `KEY=VALUE:EFFECT` (e.g. `app=production:NoSchedule`)
          - Line 2: an integer N, the number of tolerations the Pod has
          - Next N lines: each toleration in the form `KEY=VALUE`

          Print `SCHEDULED` if one of the Pod's tolerations matches the taint's key and value.
          Otherwise print `PENDING`.

          **Example:**
          ```
          app=production:NoSchedule
          2
          env=test
          app=production
          ```
          Output: `SCHEDULED`
      languages:
          - python
          - javascript
      starter_code:
          python: |
              import sys
              lines = sys.stdin.read().split('\n')
              key_value, effect = lines[0].split(':')
              key, value = key_value.split('=')
              n = int(lines[1])
              scheduled = False
              for i in range(2, 2 + n):
                  tkey, tvalue = lines[i].split('=')
                  if tkey == key and tvalue == value:
                      scheduled = True
              print('SCHEDULED' if scheduled else 'PENDING')
          javascript: |
              const lines = require('fs').readFileSync(0, 'utf8').trim().split('\n');
              const [keyValue] = lines[0].split(':');
              const [key, value] = keyValue.split('=');
              const n = parseInt(lines[1]);
              let scheduled = false;
              for (let i = 2; i < 2 + n; i++) {
                const [tkey, tvalue] = lines[i].trim().split('=');
                if (tkey === key && tvalue === value) scheduled = true;
              }
              console.log(scheduled ? 'SCHEDULED' : 'PENDING');
      test_cases:
          - stdin: |
                app=production:NoSchedule
                2
                env=test
                app=production
            expected: 'SCHEDULED'
            hidden: false
            weight: 1
          - stdin: |
                platform=production:NoSchedule
                1
                app=production
            expected: 'PENDING'
            hidden: true
            weight: 1
          - stdin: |
                version=new:NoExecute
                1
                version=new
            expected: 'SCHEDULED'
            hidden: true
            weight: 1
---
