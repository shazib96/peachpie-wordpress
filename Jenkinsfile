pipeline {
    agent any

    stages {
        stage('Git Checkout') {
            steps {
                git 'https://github.com/shazib96/peachpie-wordpress.git'
            }
        }
        stage('Deploy on production server'){
            steps {
                sshagent(['wordpress']) {               
                   sh 'ssh -o StrictHostKeyChecking=no admin1@95.216.107.123'
                   sh 'scp -r /var/lib/jenkins/workspace/wordpress-deployment/* root@95.216.107.123:/var/www/shazib.6lgx.com/html'
                }
            }
        }
    }
}
