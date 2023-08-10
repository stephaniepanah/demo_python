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

node  {
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
/*
                   stage('SonarQube Analysis') {
                       def scannerHome = tool 'sonar';
                       withSonarQubeEnv('sonar') {
                           sh "${scannerHome}/bin/sonar-scanner"
                          }
                        }  
*/
                   stage('Build docker image') {
                       this.buildImage(RepositoryName, NexusUrl, NexusRegistry, NexusUser, NexusPassword)
                        }

                   stage('Push docker image') {
		       this.pushImages(RepositoryName, imageVersion,NexusUrl, NexusRegistry, NexusUser, NexusPassword)     
                        }                        

                   stage('Remove created image') {
                       this.runDocker("rmi -f ${RepositoryName}:${imageVersion}")
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
   sh("docker build  -t ${NexusUrl}:8081/${NexusRegistry}/${RepositoryName}:${imageVersion} .")
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
                                 docker login -u \${NexusUser} -p \${NexusPassword} \${NexusUrl}
                                 docker push \${NexusUrl}:8081/\${NexusRegistry}/\${RepositoryName}:\${tag}
                                 docker rmi \${NexusUrl}:8081/\${NexusRegistry}/\${RepositoryName}:\${tag}'''
    }
}
