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
                   stage('Clone repositories') {
                         checkout scm
                       }

                   stage('Build docker image and run tests') {
                       this.buildImage(RepositoryName, NexusUrl, NexusRegistry, NexusUser, NexusPassword)
                        }

                   stage('Scan docker image') {
                       this.scanImage(RepositoryName, NexusUrl, NexusRegistry, NexusUser, NexusPassword)
                        }

                   stage('SonarQube Analysis') {
                       def scannerHome = tool 'sonar';
                       withSonarQubeEnv('sonar') {
                           sh "${scannerHome}/bin/sonar-scanner"
                          }
                        }

                   stage('Push docker image to nexus') {
                       this.pushImages(RepositoryName, NexusUrl, NexusRegistry, NexusUser, NexusPassword)
                        }

                   stage('Publish reports') {
                       publishHTML([allowMissing: true, alwaysLinkToLastBuild: true, includes: 'report.html', keepAll: true, reportDir: '.', reportFiles: 'report.html', reportName: 'Trivy Scans', reportTitles: '', useWrapperFileDirectly: true])

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
        sh("docker build -t ${NexusUrl}:8082/${NexusRegistry}/${RepositoryName}:1.0.${BUILD_ID}    .")
}

def scanImage(RepositoryName, NexusUrl, NexusRegistry, NexusUser, NexusPassword) {
        echo "Scanning ${RepositoryName}"
        env.RepositoryName = "${RepositoryName}"
        env.NexusUser = "${NexusUser}"
        env.NexusPassword = "${NexusPassword}"
        env.NexusUrl = "${NexusUrl}"
        env.NexusRegistry = "${NexusRegistry}"
        sh label: '', script: '''#!/usr/bin/env bash
                                 export DOCKER_HOST=unix:///Users/gauravkothiyal/.docker/run/docker.sock 
                                 trivy image   --dependency-tree   -s MEDIUM,HIGH,CRITICAL  --ignore-unfixed --exit-code 0   --format template --template "@html.tpl" -o report.html \${NexusUrl}:8082/\${NexusRegistry}/\${RepositoryName}:1.0.\${BUILD_ID}'''
}

def pushImages(RepositoryName, NexusUrl, NexusRegistry, NexusUser, NexusPassword) {
        echo "Pushing ${RepositoryName}"
        env.RepositoryName = "${RepositoryName}"
        env.NexusUser = "${NexusUser}"
        env.NexusPassword = "${NexusPassword}"
        env.NexusUrl = "${NexusUrl}"
        env.NexusRegistry = "${NexusRegistry}"
        sh label: '', script: '''#!/usr/bin/env bash
set -x
                                 docker login -u \${NexusUser} -p \${NexusPassword} \${NexusUrl}:8082
                                 docker push \${NexusUrl}:8082/\${NexusRegistry}/\${RepositoryName}:1.0.\${BUILD_ID}
                                 docker rmi \${NexusUrl}:8082/\${NexusRegistry}/\${RepositoryName}:1.0.\${BUILD_ID}'''
    }
