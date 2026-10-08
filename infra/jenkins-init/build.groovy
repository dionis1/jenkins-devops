import jenkins.model.Jenkins
import com.cloudbees.plugins.credentials.SystemCredentialsProvider
import com.cloudbees.plugins.credentials.CredentialsScope
import com.cloudbees.plugins.credentials.domains.Domain
import com.cloudbees.plugins.credentials.SecretBytes
import org.jenkinsci.plugins.plaincredentials.impl.FileCredentialsImpl
import hudson.slaves.DumbSlave
import hudson.slaves.JNLPLauncher
import hudson.model.Node
import jenkins.slaves.JnlpAgentReceiver

def j = Jenkins.get()
j.setNumExecutors(0)
def store = SystemCredentialsProvider.getInstance().getStore()
store.getCredentials(Domain.global()).findAll { it.id == 'kubeconfig-prod' }.each { store.removeCredentials(Domain.global(), it) }
def file = new File(j.rootDir, 'exam-kubeconfig.json')
if (file.exists()) {
    def credential = new FileCredentialsImpl(CredentialsScope.GLOBAL, 'kubeconfig', 'Renewable non-production access', 'config', SecretBytes.fromBytes(file.bytes))
    def previous = store.getCredentials(Domain.global()).find { it.id == 'kubeconfig' }
    if (previous) store.updateCredentials(Domain.global(), previous, credential)
    else store.addCredentials(Domain.global(), credential)
}
def node = j.getNode('exam-agent')
if (node != null && node.getRemoteFS() != '/home/jenkins/agent') {
    j.removeNode(node)
    node = null
}
if (node == null) {
    node = new DumbSlave('exam-agent', '/home/jenkins/agent', new JNLPLauncher(true))
    j.addNode(node)
}
node.setLabelString('docker-kubernetes')
node.setNumExecutors(1)
node.setMode(Node.Mode.EXCLUSIVE)
node.save()
def secret = new File(j.rootDir, "exam-agent.secret")
secret.text = JnlpAgentReceiver.DATABASE.getSecretOf("exam-agent")
secret.setReadable(false, false)
secret.setReadable(true, true)
secret.setWritable(false, false)
secret.setWritable(true, true)
j.save()
