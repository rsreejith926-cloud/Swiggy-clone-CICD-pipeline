pipeline {
    agent any
    tools {
        jdk 'jdk17'
        nodejs 'node23'
    }
    environment {
        SCANNER_HOME = tool 'sonar-scanner'
        // DockerHub username
        DOCKER_USER  = 'sreehub'
    }
    stages {
        stage('clean workspace') {
            steps { cleanWs() }
        }
        stage('Checkout from Git') {
            steps {
                git 'https://github.com/KastroVKiran/DevOps-Project-Swiggy.git'
            }
        }
        stage('Sonarqube Analysis') {
            steps {
                withSonarQubeEnv('sonar-server') {
                    sh ''' $SCANNER_HOME/bin/sonar-scanner -Dsonar.projectName=Swiggy \
                    -Dsonar.projectKey=Swiggy '''
                }
            }
        }
        stage('quality gate') {
            steps {
                script {
                    waitForQualityGate abortPipeline: false, credentialsId: 'Sonar-token'
                }
            }
        }
        stage('Install Dependencies') {
            steps { sh 'npm install' }
        }
        // OWASP stage is switched off (when -> false) because its first run downloads
        // a large vulnerability database and can take very long without an NVD API key.
        // To enable it, change 'false' to 'true'.
        stage('OWASP FS SCAN') {
            when { expression { return false } }
            steps {
                dependencyCheck additionalArguments: '--scan ./ --disableYarnAudit --disableNodeAudit', odcInstallation: 'DP-Check'
                dependencyCheckPublisher pattern: '**/dependency-check-report.xml'
            }
        }
        stage('TRIVY FS SCAN') {
            steps { sh 'trivy fs . > trivyfs.txt' }
        }
        stage('Docker Build & Push') {
            steps {
                script {
                    withDockerRegistry(credentialsId: 'docker-creds') {
                        sh 'docker build -t swiggy .'
                        sh 'docker tag swiggy $DOCKER_USER/swiggy:latest'
                        sh 'docker push $DOCKER_USER/swiggy:latest'
                    }
                }
            }
        }
        stage('TRIVY image scan') {
            steps { sh 'trivy image $DOCKER_USER/swiggy:latest > trivy.txt' }
        }
        stage('Deploy to container') {
            steps {
                sh 'docker rm -f swiggy || true'
                sh 'docker run -d --name swiggy -p 3000:3000 $DOCKER_USER/swiggy:latest'
            }
        }
    }
}
