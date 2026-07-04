---
kind: quiz
id_key: k8s/workloads/quiz
course: fast-kubernetes
section: workloads
section_title: "Workloads & Controllers"
section_position: 2
title: 'Quiz: Workloads & Controllers'
position: 6
estimated_minutes: 15
source: []
pass_percentage: 60
duration_minutes: 15
questions:
    - id_key: q1
      type: mcq
      difficulty: intermediate
      points: 2
      prompt: In the rolling-deployment.yaml example, a Deployment with 10 replicas sets rollingUpdate.maxUnavailable to 2 and rollingUpdate.maxSurge to 2. What do these two fields control?
      multiple: false
      options:
          - text: maxUnavailable caps how many of the 10 desired pods can be unavailable at once during the update (minimum 8 running); maxSurge caps how many extra pods above 10 can be created temporarily (maximum 12 running)
            correct: true
          - text: maxUnavailable sets the minimum number of replicas required for the Deployment to exist; maxSurge sets the maximum container image size allowed
            correct: false
          - text: They configure a DaemonSet's node toleration and readiness probe timing, not a Deployment's rollout
            correct: false
          - text: They are only used by the Recreate strategy, not RollingUpdate
            correct: false
      explanation: |
          With the RollingUpdate strategy, Kubernetes updates Pods incrementally instead of
          deleting them all at once. maxUnavailable bounds how many of the desired replicas can
          be down during the rollout, and maxSurge bounds how many pods above the desired count
          can be created temporarily to keep capacity up while old Pods are replaced.
    - id_key: q2
      type: mcq
      difficulty: intermediate
      points: 3
      prompt: The lesson's web StatefulSet sets serviceName to nginx and binds to a headless Service with clusterIP set to None. What behavior does this combination provide that a Deployment does not?
      multiple: false
      options:
          - text: Pods get stable, ordered names (web-0, web-1, web-2, ...) and can be reached individually via podName.serviceName (e.g. web-0.nginx), each with a PersistentVolumeClaim that stays bound to the same pod across restarts
            correct: true
          - text: Pods are assigned a new random name on every restart, exactly like a Deployment's ReplicaSet
            correct: false
          - text: The headless Service load-balances requests only, without exposing any individual pod DNS names
            correct: false
          - text: StatefulSets cannot use PersistentVolumeClaims; only Deployments can request persistent storage
            correct: false
      explanation: |
          A headless Service (clusterIP: None) paired with a StatefulSet's serviceName gives
          each Pod a predictable DNS name of the form podName.serviceName, and
          volumeClaimTemplates provisions a dedicated PersistentVolumeClaim per Pod that stays
          bound to the same Pod across restarts and rescheduling, unlike a Deployment's
          interchangeable, randomly-named Pods.
    - id_key: q3
      type: coding
      difficulty: intermediate
      points: 5
      prompt: |
          A Deployment's rollout history is a list of revisions in the order they were created
          (oldest first), each given as `REVISION IMAGE`. Given the history and a target
          revision number, print the image used at that revision (simulating `kubectl rollout
          undo --to-revision=N`). If the target revision is not in the list, print `not found`.

          **Example:**
          ```
          3
          1 nginx:1.18
          2 nginx:1.19
          3 httpd:2.4
          2
          ```
          Output: `nginx:1.19`
      languages:
          - python
          - javascript
      starter_code:
          python: |
              import sys
              lines = sys.stdin.read().split('\n')
              n = int(lines[0])
              revisions = {}
              for i in range(1, n + 1):
                  parts = lines[i].split()
                  revisions[int(parts[0])] = parts[1]
              target = int(lines[n + 1])
              print(revisions.get(target, 'not found'))
          javascript: |
              const lines = require('fs').readFileSync(0, 'utf8').trim().split('\n');
              const n = parseInt(lines[0]);
              const revisions = {};
              for (let i = 1; i <= n; i++) {
                const parts = lines[i].trim().split(/\s+/);
                revisions[parseInt(parts[0])] = parts[1];
              }
              const target = parseInt(lines[n + 1]);
              console.log(revisions[target] !== undefined ? revisions[target] : 'not found');
      test_cases:
          - stdin: |
                3
                1 nginx:1.18
                2 nginx:1.19
                3 httpd:2.4
                2
            expected: 'nginx:1.19'
            hidden: false
            weight: 1
          - stdin: |
                2
                1 nginx
                2 httpd
                5
            expected: 'not found'
            hidden: true
            weight: 1
          - stdin: |
                4
                1 nginx:1.16
                2 nginx:1.17
                3 nginx:1.18
                4 nginx:1.19
                4
            expected: 'nginx:1.19'
            hidden: true
            weight: 1
---
