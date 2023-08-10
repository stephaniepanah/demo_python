#!/usr/bin/env groovy
import java.text.SimpleDateFormat
import groovy.json.*

class BuildImage {
    def environment
}

properties(
        [
        disableConcurrentBuilds(),
        buildDiscarder(
            logRotator(artifactDaysToKeepStr: '1',
            artifactNumToKeepStr: '10',
            daysToKeepStr: '1',
            numToKeepStr: '10'
            )
                ),
                [$class: 'RebuildSettings', autoRebuild: false, rebuildDisabled: false],
        ]             
)

// NEXUS
def RepositoryName = 'python-demo'
def NexusUrl = "192.168.1.159"
def NexusRegistry = "demo"
 def credentials = com.cloudbees.plugins.credentials.CredentialsProvider.lookupCredentials(
                   com.cloudbees.plugins.credentials.common.StandardUsernamePasswordCredentials.class,
                   jenkins.model.Jenkins.instance
                  )
def matchingCredentials = credentials.findResult { it.id == "nexus-credentials" ? it : null }
def NexusUser = "${matchingCredentials.username}".toString()
def NexusPassword = "${matchingCredentials.password}".toString()

node ('macOS')  {
    wrap([$class: 'BuildUser']) {
    	wrap([$class: 'MaskPasswordsBuildWrapper']) {
           wrap([$class: 'TimestamperBuildWrapper'] ) {
               wrap([$class: 'AnsiColorBuildWrapper', 'colorMapName': 'xterm']) {
                  step([$class: 'WsCleanup'])
                    stage('env') {
sh "env"
}
                   stage('Clone repositories') {
                         checkout scm
                       }

                   stage('SonarQube Analysis') {
                       def scannerHome = tool 'sonar';
                       withSonarQubeEnv('sonar') {
                           sh "${scannerHome}/bin/sonar-scanner"
                          }
                        }  

                   stage('Build docker image and run tests') {
                       this.buildImage(RepositoryName, NexusUrl, NexusRegistry, NexusUser, NexusPassword)
                        }

                   stage('Scan docker image') {
                       this.scanImage(RepositoryName, NexusUrl, NexusRegistry, NexusUser, NexusPassword)
                        }

                   stage('Scan docker image') {
                     sh "trivy image ${NexusUrl}:8082/${NexusRegistry}/${RepositoryName}:${imageVersion}"
                        }

                   stage('Push docker image') {
		       this.pushImages(RepositoryName, imageVersion,NexusUrl, NexusRegistry, NexusUser, NexusPassword)     
                        }                 
       
                   stage('Publish reports') {
                       publishHTML([allowMissing: true, alwaysLinkToLastBuild: true, includes: '**/*.html,**/*.css', keepAll: true, reportDir: 'output/app/flake-report/', reportFiles: 'index.html', reportName: 'Flake8 Report', reportTitles: '', useWrapperFileDirectly: true])
                       publishHTML([allowMissing: true, alwaysLinkToLastBuild: true, includes: '**/*.html,**/*.css', keepAll: true, reportDir: 'output/app/htmlcov/', reportFiles: 'index.html', reportName: 'PyCOV Report', reportTitles: '', useWrapperFileDirectly: true])
                       publishHTML([allowMissing: true, alwaysLinkToLastBuild: true, includes: 'report.html', keepAll: true, reportDir: '.', reportFiles: 'report.html', reportName: 'HTML Report', reportTitles: '', useWrapperFileDirectly: true])

}

                    }
                }
            }     
         }
    }
def removeAutodeleteImages() {
    this.runDocker('image prune -a -f --filter "label=autodelete=true"')
    echo 'removed autodelete images'
}

def withDockerCleanup(f) {
    try {
        this.removeAutodeleteImages()
        f()
    } finally {
        this.removeAutodeleteImages()
        this.runDocker('images')
    }
}


def runDocker(command) {
    sh("sudo docker ${command}")
}

def buildImage(RepositoryName, NexusUrl, NexusRegistry, NexusUser, NexusPassword) {
        def getImagesCmd = "curl -u ${NexusUser}:${NexusPassword} -X GET 'http://${NexusUrl}:8081/service/rest/v1/search?repository=${NexusRegistry}&name=${NexusRegistry}/${RepositoryName}'"
        def findLastSemanticVerCmd = "jq -r -c --raw-output '.items[].version'  | sort"
        def incVersionCmd = 'perl -pe \'s/^((\\d+\\.)*)(\\d+)(.*)$/$1.($3+1).$4/e\''
        def fullCmd = "${getImagesCmd} | ${findLastSemanticVerCmd} | ${incVersionCmd}"
        imageVersion = sh(returnStdout: true, script: fullCmd).trim()
        if (!imageVersion) {
            imageVersion = '1.0.0'
        }
        echo 'Next Image Version: ' + imageVersion
        def gitHash=sh (returnStdout: true, script: "git rev-parse HEAD").trim()
        def dateFormat = new SimpleDateFormat("yyyy-MM-dd_HH_mm_ss")
        def date = new Date()
        def buildDate = (dateFormat.format(date)) 
   sh("docker build  -t ${NexusUrl}:8082/${NexusRegistry}/${RepositoryName}:${imageVersion} .")
}

def scanImage(RepositoryName, NexusUrl, NexusRegistry, NexusUser, NexusPassword) {
    stage('Pushing image') {
        echo "Pushing ${RepositoryName}"
        env.RepositoryName = "${RepositoryName}"
        env.NexusUser = "${NexusUser}"
        env.tag = "${tag}"
        env.NexusPassword = "${NexusPassword}"
        env.NexusUrl = "${NexusUrl}"
        env.NexusRegistry = "${NexusRegistry}"
        sh label: '', script: '''#!/usr/bin/env bash
                                 trivy image --format template --template "@html.tpl" -o report.html \${NexusUrl}:8082/\${NexusRegistry}/\${RepositoryName}:\${imageVersion}'''
  }
}
def pushImages(RepositoryName, tag,NexusUrl, NexusRegistry, NexusUser, NexusPassword) {
    stage('Pushing image') {
        echo "Pushing ${RepositoryName}"
        env.RepositoryName = "${RepositoryName}"
        env.NexusUser = "${NexusUser}"
        env.tag = "${tag}"
        env.NexusPassword = "${NexusPassword}"
        env.NexusUrl = "${NexusUrl}"
        env.NexusRegistry = "${NexusRegistry}"
        sh label: '', script: '''#!/usr/bin/env bash
set -x
                                 docker login -u \${NexusUser} -p \${NexusPassword} \${NexusUrl}:8082
                                 docker push \${NexusUrl}:8082/\${NexusRegistry}/\${RepositoryName}:\${imageVersion}
                                 docker rmi \${NexusUrl}:8082/\${NexusRegistry}/\${RepositoryName}:\${imageVersion}'''
    }
}
