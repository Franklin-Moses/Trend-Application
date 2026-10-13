Trend Application — DevOps CI/CD POC
1. Project Overview
This project demonstrates the deployment of a React application using Docker, DockerHub, Terraform, AWS, Amazon EKS, Kubernetes, Jenkins, GitHub integration, and application monitoring.
The objective is to automate the application build, container image publishing, and Kubernetes deployment through a CI/CD pipeline.
Application source: Vennilavanguvi/Trend
Project repository: Franklin-Moses/Trend-Application
DockerHub image: franklinmoses07/trend-application
AWS Region: ap-south-1 (Mumbai)
Application port: 3000
Resource status: AWS infrastructure was provisioned and tested for the POC, then destroyed after validation to avoid ongoing AWS charges. The commands in this document explain how the environment can be recreated; running them may incur AWS costs.
2. Architecture
The POC follows this workflow:
1.	Developer pushes source-code changes to GitHub.
2.	GitHub webhook triggers the Jenkins pipeline.
3.	Jenkins checks out the source code.
4.	Jenkins builds the Docker image.
5.	Jenkins authenticates with DockerHub and pushes the image.
6.	Jenkins connects to Amazon EKS and applies Kubernetes deployment and service manifests.
7.	Kubernetes starts the application pods and exposes the application through a LoadBalancer service.
8.	Monitoring tools are used to observe application or cluster health.
Technology stack: React, Docker, DockerHub, Terraform, AWS VPC, IAM, EC2, Jenkins, Amazon EKS, Kubernetes, GitHub, and Prometheus monitoring.
3. Application Setup
Prerequisites
Install and configure the following tools as required:
•	Git
•	Node.js and npm
•	Docker Desktop
•	Terraform
•	AWS CLI
•	kubectl
•	An AWS account with appropriately scoped permissions
•	A DockerHub account and GitHub repository
Clone the source repository
git clone https://github.com/Vennilavanguvi/Trend.git
cd Trend
Install dependencies and build the React application using the project's supported package scripts:
npm install
npm run build
The Dockerfile used in this POC serves the generated dist/ directory through NGINX.
4. Docker Containerization
The Dockerfile uses NGINX to serve the production build.
FROM nginx:alpine
COPY dist/ /usr/share/nginx/html/
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]

Build the image from the project root:  docker build -t trend-app:latest .

Run the container and expose the application on local port 3000:
docker run -d --name trend-app-container -p 3000:80 trend-app:latest

Open the application at: http://localhost:3000

Verify the container:
docker ps
docker logs trend-app-container

When the local test is complete, stop and remove the test container:
docker stop trend-app-container
docker rm trend-app-container

5. DockerHub Image Publishing
A DockerHub repository was created for the application.
Repository: franklinmoses07/trend-application
Image tag: latest

Tag and push the image:
docker tag trend-app:latest franklinmoses07/trend-application:latest
docker login
docker push franklinmoses07/trend-application:latest

Verify that the published image can be pulled:
docker pull franklinmoses07/trend-application:latest
DockerHub stores the container image so that Jenkins and Kubernetes can retrieve it during deployment.

6. Terraform and AWS Infrastructure
Terraform was used to define and provision the AWS infrastructure required by the POC.
The infrastructure configuration includes:
•	VPC and networking resources
•	Public subnets, Internet Gateway, route table, and security groups
•	IAM roles and policy attachments for EC2 and EKS
•	EC2 instance configured for Jenkins
•	Amazon EKS cluster
•	EKS worker node group
•	EKS access configuration required for deployment
•	Networking and permissions required for Kubernetes application exposure

Provisioning instructions
Open PowerShell in the Terraform directory:
cd "D:\Project 2\Trend-Application\terraform"
Initialize and validate Terraform:
terraform init
terraform fmt -check
terraform validate
terraform plan
Review the plan carefully before provisioning:
terraform apply
Type yes only after reviewing the resources, costs, permissions, and configuration.
Important: These commands are for reproducing the environment, not for the current cleaned-up environment. Provisioning may incur AWS charges. Never commit AWS credentials, Terraform state files, or secret values to GitHub.
7. Jenkins Configuration
Jenkins was hosted on an AWS EC2 instance for the POC.
The Jenkins environment was configured for source-code retrieval, container image building and publishing, and Kubernetes deployment.
Relevant plugins and integrations include:
•	Git and GitHub integration
•	Pipeline
•	Docker-related build and image-publishing support
•	Kubernetes deployment through command-line tooling
•	GitHub webhook or generic webhook trigger integration
Credentials
Jenkins credentials should be stored in the Jenkins Credentials store rather than hardcoded in a pipeline.
The DockerHub credential ID used in the pipeline was:
dockerhub-credentials
Configure AWS and Kubernetes access with the least privileges necessary. Do not store passwords, access keys, tokens, or kubeconfig secrets in the repository.
8. Declarative CI/CD Pipeline
The Jenkins pipeline automates the following stages:
1.	Checkout: retrieves the application source from GitHub.
2.	Build: builds the Docker image from the Dockerfile.
3.	Publish: authenticates with DockerHub and pushes franklinmoses07/trend-application:latest.
4.	Deploy: applies the Kubernetes manifests to the configured EKS cluster.
5.	Verify: checks deployment rollout status and application pods.
The repository's Jenkinsfile, where present, contains the pipeline implementation and should be used as the source of truth for the actual stage names and commands.
GitHub webhook integration
The repository was integrated with Jenkins so that source-code changes could trigger a pipeline build.
For a reproducible setup:
1.	Configure the GitHub repository in the Jenkins job.
2.	Configure the webhook endpoint and trigger option supported by the Jenkins integration.
3.	Ensure Jenkins is reachable by GitHub and that webhook requests are handled securely.
4.	Push a harmless source-code change.
5.	Verify the webhook delivery in GitHub and the corresponding Jenkins build.
6.	Confirm that the build, push, and deployment stages complete successfully.
9. Kubernetes Deployment
The Kubernetes manifests are stored in the k8s/ directory:
•	k8s/deployment.yaml
•	k8s/service.yaml
The deployment defines the application container and replica configuration. The service exposes the application through a Kubernetes LoadBalancer service.
Apply the manifests when an EKS cluster is available and the current AWS identity has the required access:
aws eks update-kubeconfig --region ap-south-1 --name trend-eks
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml

Verify the deployment:
kubectl get nodes
kubectl get deployments
kubectl get pods
kubectl rollout status deployment/trend-application
kubectl get services

Check the service's external hostname:
kubectl get service trend-application-service
The external hostname is assigned by AWS and may take several minutes to appear. The exact service name, image tag, and port configuration should match the manifests committed to the repository.


10. Monitoring
Monitoring was included in the POC evidence using Prometheus-related monitoring.
A repeatable monitoring setup should verify:
•	Cluster and node health
•	Pod readiness and restart counts
•	Deployment availability
•	Application health and access
•	Relevant monitoring targets and metrics

Example Kubernetes health checks:
kubectl get nodes
kubectl get pods --all-namespaces
kubectl get events --sort-by=.metadata.creationTimestamp
Monitoring dashboards, targets, and metric collection should be validated in the recreated environment. Do not assume that monitoring services remain available after the AWS infrastructure is destroyed.

11. Git and Repository Hygiene
The project uses GitHub for source-code version control.
Review the .gitignore and .dockerignore files before committing changes. These should exclude appropriate local files, dependencies, build artefacts where suitable, secrets, and Terraform-generated state or backup files.
Typical Git commands:
git status
git add README.md
git commit -m "Add DevOps POC README"
git push origin main
Review git status before staging other files. Avoid git add . when untracked files may include Terraform state, backups, credentials, or temporary files.
12. Validation Results
The following POC activities were performed and validated during the deployment session:
•	React application production build and local Docker testing
•	Docker image build and DockerHub publishing
•	Terraform provisioning of AWS infrastructure
•	Jenkins pipeline execution for image publishing and EKS deployment
•	Kubernetes deployment and service creation
•	Two application pods reaching the Running/Ready state
•	Application access through the Kubernetes LoadBalancer
•	GitHub-triggered pipeline activity, as recorded in the project evidence
These results describe the earlier test environment. The AWS resources were subsequently destroyed, so the application and its LoadBalancer are not currently hosted by that environment.

13. LoadBalancer Submission Evidence
AWS Region: ap-south-1
Kubernetes service: trend-application-service
Historical LoadBalancer DNS:
ab288dd337b294281aa64755e3a7eea8-1855033945.ap-south-1.elb.amazonaws.com
The service created an AWS Classic Elastic Load Balancer. Classic ELBs do not use the same ARN format as ELBv2 load balancers. The load balancer was deleted during cleanup, so the hostname is retained here as historical deployment evidence only.
For the submission, attached the captured Kubernetes service output and application-access screenshot. If the evaluator specifically requires an ARN, explain that the POC used a Classic ELB and provide its recorded name and DNS along with the service screenshot, rather than inventing an ARN.

14. Screenshots and Evidence Document
Attached the separate evidence document containing the screenshots captured during the POC. Recommended evidence includes:
1.	GitHub repository and source code
2.	Application running locally on port 3000
3.	Dockerfile and successful Docker image build
4.	DockerHub repository and pushed image
5.	Terraform configuration and successful infrastructure provisioning
6.	Jenkins installation and plugin configuration
7.	GitHub webhook configuration and successful delivery/build evidence
8.	Jenkins pipeline stages and successful completion
9.	EKS cluster and worker node validation
10.	Kubernetes deployment, running pods, and service
11.	Application opened through the LoadBalancer
12.	Monitoring dashboard or Prometheus evidence
13.	Final AWS cleanup evidence, if required
Use actual screenshots from the project. Do not insert placeholder screenshots or claim a screenshot exists if it was not captured.

15. Conclusion
This POC demonstrates an end-to-end DevOps workflow for a React application using containerization, infrastructure as code, CI/CD automation, Kubernetes orchestration, cloud networking, and monitoring.
The project was tested in AWS, and the resources were destroyed after validation to reduce ongoing costs. The source repository and published DockerHub image remain available for review and future reproduction of the deployment.

