#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# scripts/setup-jenkins.sh — One-time Jenkins install on a Debian/Ubuntu k3s
# box. Afterwards Jenkins polls GitHub every 2 minutes and runs ./Jenkinsfile,
# which builds + deploys MindForge to k3s. Idempotent; run on any machine to
# make it a deploy host.
#
# Usage: sudo SECRETS_FILE=/path/to/secrets.env [GIT_TOKEN=ghp_...] \
#          [REPO_URL=...] [BRANCH=master] bash scripts/setup-jenkins.sh
#   SECRETS_FILE  Filled-in copy of k8s/overlays/local/secrets.env. Imported
#                 into Jenkins as the "mindforge-secrets-env" credential.
#   GIT_TOKEN     GitHub PAT, only if the repo is private.
# Writes the generated admin password to /var/lib/jenkins/admin-password.txt.
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/nayanjaiswal1/lms.git}"
BRANCH="${BRANCH:-master}"
SECRETS_FILE="${SECRETS_FILE:-}"
GIT_TOKEN="${GIT_TOKEN:-}"
PLUGINS="workflow-aggregator git credentials-binding plain-credentials"
JENKINS_HOME=/var/lib/jenkins
PM_VERSION=2.13.2

[[ $EUID -eq 0 ]] || { echo "Run with sudo." >&2; exit 1; }
[[ -f "$SECRETS_FILE" ]] || { echo "SECRETS_FILE must point to an existing secrets.env." >&2; exit 1; }
command -v k3s &>/dev/null || { echo "k3s not found — run scripts/setup-k3s-local.sh first." >&2; exit 1; }

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq ca-certificates curl gnupg git rsync fontconfig openjdk-21-jre-headless docker.io

if ! command -v jenkins &>/dev/null; then
  curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key -o /usr/share/keyrings/jenkins-keyring.asc
  echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" > /etc/apt/sources.list.d/jenkins.list
  apt-get update -qq
  apt-get install -y -qq jenkins
fi
systemctl stop jenkins

# Jenkins builds images (docker), imports them (sudo k3s ctr), and runs kubectl/helm.
usermod -aG docker jenkins
echo "jenkins ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/jenkins-deploy
chmod 440 /etc/sudoers.d/jenkins-deploy
visudo -cf /etc/sudoers.d/jenkins-deploy >/dev/null
install -d -o jenkins -g jenkins -m 700 "$JENKINS_HOME/.kube"
install -o jenkins -g jenkins -m 600 /etc/rancher/k3s/k3s.yaml "$JENKINS_HOME/.kube/config"

# Plugins, pre-installed so the setup wizard is not needed.
curl -fsSL -o /tmp/jpm.jar \
  "https://github.com/jenkinsci/plugin-installation-manager-tool/releases/download/${PM_VERSION}/jenkins-plugin-manager-${PM_VERSION}.jar"
sudo -u jenkins java -jar /tmp/jpm.jar --war /usr/share/java/jenkins.war \
  --plugin-download-directory "$JENKINS_HOME/plugins" --plugins $PLUGINS

# Admin user, credentials, and the pipeline job — created on first start.
ADMIN_PW_FILE="$JENKINS_HOME/admin-password.txt"
[[ -f "$ADMIN_PW_FILE" ]] || { head -c 18 /dev/urandom | base64 | tr -d '/+=' > "$ADMIN_PW_FILE"; }
install -d -o jenkins -g jenkins "$JENKINS_HOME/init.groovy.d"
install -o jenkins -g jenkins -m 600 "$SECRETS_FILE" "$JENKINS_HOME/secrets.env.import"
chown jenkins:jenkins "$ADMIN_PW_FILE"; chmod 600 "$ADMIN_PW_FILE"
echo "$GIT_TOKEN" > "$JENKINS_HOME/git-token.import"; chown jenkins:jenkins "$JENKINS_HOME/git-token.import"; chmod 600 "$JENKINS_HOME/git-token.import"

cat > "$JENKINS_HOME/init.groovy.d/mindforge.groovy" <<GROOVY
import jenkins.model.*
import hudson.security.*
import com.cloudbees.plugins.credentials.*
import com.cloudbees.plugins.credentials.domains.Domain
import com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl
import org.jenkinsci.plugins.plaincredentials.impl.FileCredentialsImpl
import org.jenkinsci.plugins.workflow.job.WorkflowJob
import org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition
import hudson.plugins.git.*
import hudson.triggers.SCMTrigger

def j = Jenkins.get()
def home = j.rootDir
def adminPw = new File(home, 'admin-password.txt').text.trim()
def realm = new HudsonPrivateSecurityRealm(false)
if (realm.getUser('admin') == null) realm.createAccount('admin', adminPw)
j.setSecurityRealm(realm)
def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
strategy.setAllowAnonymousRead(false)
j.setAuthorizationStrategy(strategy)

def store = SystemCredentialsProvider.instance.store
def secrets = new File(home, 'secrets.env.import')
if (secrets.exists() && CredentialsProvider.lookupCredentials(FileCredentialsImpl, j, null, null).every { it.id != 'mindforge-secrets-env' }) {
  store.addCredentials(Domain.global(), new FileCredentialsImpl(CredentialsScope.GLOBAL, 'mindforge-secrets-env', 'MindForge k8s secrets.env', 'secrets.env', com.cloudbees.plugins.credentials.SecretBytes.fromBytes(secrets.bytes)))
}
def token = new File(home, 'git-token.import').text.trim()
def credId = null
if (token) {
  credId = 'mindforge-github'
  if (CredentialsProvider.lookupCredentials(UsernamePasswordCredentialsImpl, j, null, null).every { it.id != credId }) {
    store.addCredentials(Domain.global(), new UsernamePasswordCredentialsImpl(CredentialsScope.GLOBAL, credId, 'GitHub token', 'x-access-token', token))
  }
}

if (j.getItem('mindforge') == null) {
  def job = j.createProject(WorkflowJob, 'mindforge')
  def scm = new GitSCM(GitSCM.createRepoList('${REPO_URL}', credId), [new BranchSpec('*/${BRANCH}')], false, [], null, null, [])
  job.definition = new CpsScmFlowDefinition(scm, 'Jenkinsfile')
  job.addTrigger(new SCMTrigger('H/2 * * * *'))
  job.save()
  job.scheduleBuild2(0)
}
j.save()
GROOVY
chown jenkins:jenkins "$JENKINS_HOME/init.groovy.d/mindforge.groovy"
touch "$JENKINS_HOME/jenkins.install.InstallUtil.lastExecVersion"
echo 2.0 > "$JENKINS_HOME/jenkins.install.UpgradeWizard.state"

systemctl enable --now jenkins
echo "Jenkins is starting on http://$(hostname):8080 — user: admin, password in ${ADMIN_PW_FILE}"
echo "First build starts automatically; later pushes to ${BRANCH} deploy within ~2 minutes."
