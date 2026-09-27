---
kind: quiz
id_key: k8s/pod-fundamentals/quiz
course: fast-kubernetes
section: pod-fundamentals
section_title: Pods
section_position: 2
title: 'Quiz: Pods'
position: 2
estimated_minutes: 10
source:
  - K8s-CreatingPod-Imperative.md
  - K8-CreatingPod-Declerative.md
  - K8s-Multicontainer-Sidecar.md
pass_percentage: 70
duration_minutes: 15
questions:
  - id_key: q1
    type: mcq
    difficulty: beginner
    points: 1
    prompt: Which statement best describes a pod?
    options:
      - text: A virtual machine that runs one container
        correct: false
      - text: One or more containers that are scheduled together and share an IP address and volumes
        correct: true
      - text: A group of nodes
        correct: false
      - text: A saved copy of a container image
        correct: false
    explanation: A pod is the smallest deployable unit. Its containers share one network namespace (one IP, localhost between them) and can share volumes.
  - id_key: q2
    type: mcq
    difficulty: beginner
    points: 1
    prompt: A pod stays in CrashLoopBackOff. Which command is the best first step to find out why the app dies?
    options:
      - text: kubectl logs <pod> --previous
        correct: true
      - text: kubectl get nodes
        correct: false
      - text: kubectl delete pod <pod>
        correct: false
      - text: kubectl scale --replicas=0
        correct: false
    explanation: CrashLoopBackOff means the process keeps exiting. The logs of the previous (crashed) container usually show the error.
  - id_key: q3
    type: mcq
    difficulty: beginner
    points: 1
    prompt: A pod has been Pending for 10 minutes. What does that usually mean?
    options:
      - text: The app inside is crashing
        correct: false
      - text: It has not started yet, often because no node has enough resources or no node matches its scheduling rules
        correct: true
      - text: The pod finished its work successfully
        correct: false
      - text: The pod is being deleted
        correct: false
    explanation: 'Pending means the pod is not running yet. `kubectl describe pod` shows the scheduler''s reason in Events, for example "0/3 nodes are available: insufficient memory".'
  - id_key: q4
    type: mcq
    difficulty: beginner
    points: 1
    prompt: What is the sidecar pattern?
    options:
      - text: Running two copies of the same app in different pods
        correct: false
      - text: A helper container in the same pod as the main app, for example a log shipper or proxy
        correct: true
      - text: A pod that runs only on the control plane
        correct: false
      - text: A backup node for a failed node
        correct: false
    explanation: A sidecar lives in the same pod so it shares the app's network and volumes.
  - id_key: q5
    type: mcq
    difficulty: intermediate
    points: 1
    prompt: What happens to data in an emptyDir volume when one container in the pod restarts (but the pod is not deleted)?
    options:
      - text: The data is lost
        correct: false
      - text: The data is kept, because emptyDir lives as long as the pod
        correct: true
      - text: The data is moved to etcd
        correct: false
      - text: The whole pod is recreated
        correct: false
    explanation: emptyDir belongs to the pod, not the container. It survives container restarts and is removed only when the pod is removed from the node.
  - id_key: q6
    type: mcq
    difficulty: intermediate
    points: 1
    prompt: When do init containers run?
    options:
      - text: In parallel with the app containers
        correct: false
      - text: Before the app containers, one at a time, and each must succeed
        correct: true
      - text: After the app containers exit
        correct: false
      - text: Only when the pod is deleted
        correct: false
    explanation: Init containers run sequentially to completion before any app container starts.
  - id_key: q7
    type: mcq
    difficulty: beginner
    points: 1
    prompt: Which restartPolicy should a long-running web server use?
    options:
      - text: Never
        correct: false
      - text: OnFailure
        correct: false
      - text: Always
        correct: true
      - text: OnSuccess
        correct: false
    explanation: A server should always come back if it exits. Always is also the default.
  - id_key: q8
    type: mcq
    difficulty: beginner
    points: 1
    prompt: What does `kubectl port-forward pod/web 9000:80` do?
    options:
      - text: Changes the pod's container port to 9000
        correct: false
      - text: Opens port 9000 on your machine and tunnels it to port 80 of the pod
        correct: true
      - text: Creates a Service on port 9000
        correct: false
      - text: Opens port 9000 on every node
        correct: false
    explanation: port-forward is a temporary tunnel for testing. It creates no Kubernetes object.
---
