pipeline {
    agent any

    parameters {
        string(name: 'GIT_BRANCH', defaultValue: 'main', description: 'Rama del repositorio')
        string(name: 'REMOTE_HOST', defaultValue: 'ec2-13-40-134-57.eu-west-2.compute.amazonaws.com', description: 'Host remoto')
        string(name: 'REMOTE_USER', defaultValue: 'ec2-user', description: 'Usuario SSH remoto')
        string(name: 'REMOTE_SCRIPT_DIR', defaultValue: '', description: 'Directorio remoto donde copiar el script')
        string(name: 'REMOTE_SCRIPT_NAME', defaultValue: 'shell_script.sh', description: 'Nombre del script remoto')
    }

    environment {
        SSH_CREDENTIALS_ID = 'ssh-healthconnect-remote'
    }

    stages {

        stage('Validar script') {
            steps {
                sshagent(credentials: ["${env.SSH_CREDENTIALS_ID}"]) {
                    sh '''
                        set -eu
                        
                        ssh -o StrictHostKeyChecking=no "${REMOTE_USER}@${REMOTE_HOST}" \
                          "sudo test -f '/${REMOTE_SCRIPT_NAME}' | sudo chmod +x '/${REMOTE_SCRIPT_NAME}'"
                    '''
                }
            }
        }

        stage('Ejecutar script remoto') {
            steps {
                sshagent(credentials: ["${env.SSH_CREDENTIALS_ID}"]) {
                    sh '''
                        set -eu

                        ssh -o StrictHostKeyChecking=no "${REMOTE_USER}@${REMOTE_HOST}" \
                          "sudo sh '/${REMOTE_SCRIPT_NAME}' | tee remote_execution.log"
                    '''
                }
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'remote_execution.log', allowEmptyArchive: true
        }
        success {
            echo 'Despliegue remoto completado correctamente.'
        }
        failure {
            echo 'El despliegue remoto ha fallado. Revisa remote_execution.log.'
        }
    }
}