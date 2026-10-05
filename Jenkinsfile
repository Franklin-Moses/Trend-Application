pipeline {
    agent any

    environment {
        IMAGE = 'franklinmoses07/trend-application:latest'
    }

    stages {

        stage('Build Docker Image') {
            steps {
                sh '''
                    docker build -t "$IMAGE" .
                '''
            }
        }

        stage('Login to Docker Hub') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'dockerhub-credentials',
                        usernameVariable: 'DOCKERHUB_USER',
                        passwordVariable: 'DOCKERHUB_TOKEN'
                    )
                ]) {
                    sh '''
                        echo "$DOCKERHUB_TOKEN" | docker login \
                            -u "$DOCKERHUB_USER" \
                            --password-stdin
                    '''
                }
            }
        }

        stage('Push Docker Image') {
            steps {
                sh '''
                    docker push "$IMAGE"
                '''
            }
        }

        stage('Deploy to EKS') {
            steps {
                sh '''
                    aws eks update-kubeconfig \
                        --region ap-south-1 \
                        --name trend-eks

                    kubectl apply \
                        -f k8s/deployment.yaml

                    kubectl apply \
                        -f k8s/service.yaml

                    kubectl rollout restart \
                        deployment/trend-application

                    kubectl rollout status \
                        deployment/trend-application \
                        --timeout=180s
                '''
            }
        }

        stage('Verify Deployment') {
            steps {
                sh '''
                    echo "===== PODS ====="
                    kubectl get pods -o wide

                    echo "===== SERVICE ====="
                    kubectl get svc trend-application-service
                '''
            }
        }
    }

    post {
        always {
            sh 'docker logout || true'
        }
    }
}