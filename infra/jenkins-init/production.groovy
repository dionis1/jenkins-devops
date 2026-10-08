import jenkins.model.Jenkins
import com.cloudbees.plugins.credentials.SystemCredentialsProvider
import com.cloudbees.plugins.credentials.CredentialsScope
import com.cloudbees.plugins.credentials.domains.Domain
import com.cloudbees.plugins.credentials.SecretBytes
import org.jenkinsci.plugins.plaincredentials.impl.FileCredentialsImpl
import org.jenkinsci.plugins.workflow.job.WorkflowJob
import org.jenkinsci.plugins.workflow.cps.CpsFlowDefinition

def j = Jenkins.get()
// Import only the explicitly designated initial administrator. Preserve all
// original user files; directory hashes differ between Jenkins instances.
def imported = new File(j.rootDir, 'exam-admin-imported')
if (!imported.exists()) {
    new File(j.rootDir, 'users').listFiles()?.findAll { it.isDirectory() }.each { directory ->
        def config = new File(directory, 'config.xml')
        if (config.exists()) {
            def id = new XmlSlurper().parse(config).id.text()
            if (id.equalsIgnoreCase('admindf')) {
                def user = hudson.model.User.getById(id, true)
                def target = new File(user.getRootDir(), 'config.xml')
                if (target.canonicalPath != config.canonicalPath) {
                    target.parentFile.mkdirs()
                    target.bytes = config.bytes
                    user.reload()
                }
                imported.text = 'Initial administrator imported; source files preserved.'
            }
        }
    }
}
// This controller runs only a fixed, administrator-owned production pipeline.
j.setNumExecutors(1)
j.setSlaveAgentPort(-1)
def file = new File(j.rootDir, 'exam-kubeconfig.json')
if (file.exists()) {
    def store = SystemCredentialsProvider.getInstance().getStore()
    def credential = new FileCredentialsImpl(CredentialsScope.GLOBAL, 'kubeconfig-prod', 'Renewable production-only access', 'config', SecretBytes.fromBytes(file.bytes))
    def previous = store.getCredentials(Domain.global()).find { it.id == 'kubeconfig-prod' }
    if (previous) store.updateCredentials(Domain.global(), previous, credential)
    else store.addCredentials(Domain.global(), credential)
}
def job = j.getItem('production-master') ?: j.createProject(WorkflowJob, 'production-master')
job.addProperty(new hudson.model.ParametersDefinitionProperty(new hudson.model.StringParameterDefinition('IMAGE_TAG', '', 'Successful current master image tag')))
def definition = new File('/opt/exam/Jenkinsfile.production').text
assert org.jenkinsci.plugins.pipeline.modeldefinition.parser.Converter.scriptToPipelineDef(definition) != null
println('Production pipeline validation passed')
job.setDefinition(new CpsFlowDefinition(definition, true))
job.save()
j.save()
