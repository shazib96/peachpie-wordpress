pipeline {
    agent any

    stages {
        stage('Git Checkout') {
            steps {
                git branch: 'master', url: 'https://github.com/shazib96/peachpie-wordpress.git'
            }
        }
        stage('Deploy on prod server'){
            steps {
                sshagent(['latest']) {
                   sh 'ssh -o StrictHostKeyChecking=no admin1@95.216.107.123'
                   sh 'scp /var/lib/jenkins/workspace/wordpress-deployment/* admin1@95.216.107.123:/var/www/shazib.6lgx.com/html'
                }
            }
        }
    }
}
