// Poll GitHub, build, and deploy MindForge to a k3s box.
// DEPLOY_TARGET=local deploys to the machine running this agent;
// user@host deploys to another k3s box over SSH (scripts/deploy-remote-k3s.sh).
// Setup: scripts/setup-jenkins.sh. Secrets file lives in the Jenkins credential
// "mindforge-secrets-env" (never in git).
pipeline {
  agent { label 'built-in' } // must run on the k3s host (docker, kubectl, helm, rsync), not a container agent
  options { disableConcurrentBuilds(); timeout(time: 90, unit: 'MINUTES') }
  triggers { pollSCM('H/2 * * * *') } // LAN-only host: no GitHub webhook can reach it
  parameters {
    string(name: 'DEPLOY_TARGET', defaultValue: 'local', description: 'local, or user@host of another k3s machine')
    string(name: 'DOMAIN', defaultValue: '', description: 'Hostname to serve on; blank = mindforge.<hostname>.local')
  }
  stages {
    stage('Prepare') {
      steps {
        withCredentials([file(credentialsId: 'mindforge-secrets-env', variable: 'SECRETS_FILE')]) {
          sh 'install -m 600 "$SECRETS_FILE" k8s/overlays/local/secrets.env'
        }
        script {
          env.APP_DOMAIN = params.DOMAIN?.trim() ?: sh(script: 'echo "mindforge.$(hostname).local"', returnStdout: true).trim()
        }
        sh '''
          sed -i "s/mindforge\\.127\\.0\\.0\\.1\\.nip\\.io/${APP_DOMAIN}/g" \
            k8s/overlays/local/configmap-domain.patch.yaml k8s/overlays/local/kustomization.yaml
        '''
      }
    }
    stage('Deploy') {
      steps {
        sh '''
          export DOMAIN="$APP_DOMAIN" KUBECONFIG="$HOME/.kube/config"
          if [ "$DEPLOY_TARGET" = "local" ]; then
            bash scripts/bootstrap-k3s-local.sh
          else
            bash scripts/deploy-remote-k3s.sh "$DEPLOY_TARGET" "$APP_DOMAIN"
          fi
        '''
      }
    }
  }
  post {
    always { sh 'rm -f k8s/overlays/local/secrets.env' }
    success { echo "Deployed: https://${env.APP_DOMAIN}" }
  }
}
