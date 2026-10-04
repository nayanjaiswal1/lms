---
kind: quiz
id_key: k8s/workloads/quiz
course: fast-kubernetes
section: workloads
section_title: Deployments & Workload Controllers
section_position: 3
title: 'Quiz: Deployments & Workload Controllers'
position: 7
estimated_minutes: 12
source:
  - K8s-Deployment.md
  - K8s-Rollout-Rollback.md
  - K8s-Daemon-Sets.md
  - K8s-Statefulset.md
  - K8s-Job.md
  - K8s-CronJob.md
pass_percentage: 70
duration_minutes: 20
questions:
  - id_key: q1
    type: mcq
    difficulty: beginner
    points: 1
    prompt: What object does a Deployment create directly to keep the right number of pods running?
    options:
      - text: A StatefulSet
        correct: false
      - text: A ReplicaSet
        correct: true
      - text: A DaemonSet
        correct: false
      - text: A Job
        correct: false
    explanation: Deployment → ReplicaSet → Pods. Each version of the pod template gets its own ReplicaSet.
  - id_key: q2
    type: mcq
    difficulty: intermediate
    points: 1
    prompt: A Deployment with 4 replicas uses RollingUpdate with maxSurge 1 and maxUnavailable 0. What does that guarantee during an update?
    options:
      - text: All 4 pods are replaced at the same moment
        correct: false
      - text: There are always at least 4 ready pods; one extra new pod is started and must be ready before an old one is removed
        correct: true
      - text: Only one pod runs during the update
        correct: false
      - text: The update is paused until you resume it
        correct: false
    explanation: maxUnavailable 0 keeps capacity at 4 ready pods; maxSurge 1 allows one extra pod at a time. This is the safest, slowest setting.
  - id_key: q3
    type: mcq
    difficulty: beginner
    points: 1
    prompt: Which command returns a Deployment to its previous version?
    options:
      - text: kubectl rollout undo deployment/web
        correct: true
      - text: kubectl rollout pause deployment/web
        correct: false
      - text: kubectl rollback web
        correct: false
      - text: kubectl apply --previous -f web.yaml
        correct: false
    explanation: rollout undo switches back to the previous ReplicaSet's template (or a specific one with --to-revision).
  - id_key: q4
    type: mcq
    difficulty: beginner
    points: 1
    prompt: You need a monitoring agent on every node, including nodes added later. Which workload do you use?
    options:
      - text: Deployment
        correct: false
      - text: DaemonSet
        correct: true
      - text: CronJob
        correct: false
      - text: StatefulSet
        correct: false
    explanation: A DaemonSet runs one pod per eligible node and follows nodes as they join and leave.
  - id_key: q5
    type: mcq
    difficulty: intermediate
    points: 1
    prompt: Which feature does a StatefulSet provide that a Deployment does not?
    options:
      - text: Automatic data replication between pods
        correct: false
      - text: Stable pod names (app-0, app-1) and a separate PersistentVolumeClaim per pod
        correct: true
      - text: Running one pod on every node
        correct: false
      - text: Automatic scaling based on CPU
        correct: false
    explanation: StatefulSets give identity and per-pod storage. Replication between members is the application's own job.
  - id_key: q6
    type: mcq
    difficulty: intermediate
    points: 1
    prompt: What is a headless Service?
    options:
      - text: A Service with clusterIP None, whose DNS name returns the pod IPs directly
        correct: true
      - text: A Service without a selector
        correct: false
      - text: A Service that is only reachable from outside the cluster
        correct: false
      - text: A Service without ports
        correct: false
    explanation: Headless Services skip the virtual IP. StatefulSets use them so each pod gets its own DNS name, like web-0.nginx.
  - id_key: q7
    type: mcq
    difficulty: beginner
    points: 1
    prompt: A Job has completions 5 and parallelism 5. What happens?
    options:
      - text: 5 pods run at the same time, and the Job is complete when all 5 succeed
        correct: true
      - text: 1 pod runs 5 times in a row
        correct: false
      - text: 25 pods are created
        correct: false
      - text: The pods run forever
        correct: false
    explanation: parallelism is how many run at once; completions is how many successes are needed.
  - id_key: q8
    type: mcq
    difficulty: beginner
    points: 1
    prompt: What does the cron schedule `0 */6 * * *` mean?
    options:
      - text: Every 6 minutes
        correct: false
      - text: At minute 0 of every 6th hour (00:00, 06:00, 12:00, 18:00)
        correct: true
      - text: On the 6th day of every month
        correct: false
      - text: Every day at 06:00 only
        correct: false
    explanation: The second field is the hour. */6 means every 6 hours; the first field 0 means at minute 0.
  - id_key: q9
    type: mcq
    difficulty: intermediate
    points: 1
    prompt: You changed a ConfigMap that a Deployment reads as environment variables. How do you make the running pods pick up the new values?
    options:
      - text: They update automatically within seconds
        correct: false
      - text: Run kubectl rollout restart deployment/<name> to replace the pods
        correct: true
      - text: Run kubectl rollout undo
        correct: false
      - text: Delete the ConfigMap
        correct: false
    explanation: Environment variables are read only when a container starts. A rollout restart replaces pods gradually so they read the new values.
---
