# Swiggy Clone: CI/CD Pipeline on AWS (Terraform + Jenkins + SonarQube + Trivy + Docker)

A hands-on DevOps project that builds a CI/CD pipeline for a React "Swiggy clone" app on a single AWS EC2 server, provisioned with Terraform. Based on the tutorial project [KastroVKiran/DevOps-Project-Swiggy](https://github.com/KastroVKiran/DevOps-Project-Swiggy), updated to work with a current AWS Free plan account and current tool versions (October 2026).

## What it does

1. **Terraform** creates a security group and one Ubuntu 22.04 EC2 instance (`m7i-flex.large`, 8 GB RAM, 20 GB gp3 disk) in `ap-south-1`.
2. A **user-data script** (`resource.sh`) installs Java 21, Jenkins, Docker, a SonarQube container and Trivy.
3. A **Jenkins pipeline** then runs these stages:
   - checkout from Git
   - SonarQube code analysis and quality gate
   - `npm install`
   - Trivy filesystem scan
   - Docker image build and push to DockerHub
   - Trivy image scan
   - deploy the container on port 3000

```
Git repo -> Jenkins -> SonarQube (analysis) -> npm install -> Trivy (files)
                                         -> Docker build & push -> Trivy (image) -> run container :3000
```

## Files

| File | Purpose |
|---|---|
| `provider.tf` | AWS provider, region `ap-south-1` |
| `Main.tf` | Security group (your IP only), EC2 instance, public IP output |
| `resource.sh` | User-data install script for the server |
| `Jenkinsfile` | The pipeline definition |
| `terraform.tfvars` | Your own values (not committed, see `.gitignore`) |

## Prerequisites

- An AWS account and an IAM user with `AmazonEC2FullAccess` (do not use root access keys)
- AWS CLI and Terraform installed and configured (`aws configure`, region `ap-south-1`)
- An EC2 key pair named `swiggy-key` in `ap-south-1`
- A DockerHub account and an access token

## Setup

1. Create the key pair and keep the file safe (AWS shows it only once):
   ```
   aws ec2 create-key-pair --key-name swiggy-key --region ap-south-1 --query 'KeyMaterial' --output text > ~/.ssh/swiggy-key.pem
   chmod 400 ~/.ssh/swiggy-key.pem
   ```
2. Create `terraform.tfvars` with your public IP (find it with `curl -4 ifconfig.me`):
   ```
   my_ip = "YOUR.IP.HERE/32"
   ```
3. Build the server:
   ```
   terraform init
   terraform plan
   terraform apply
   ```
4. SSH in and wait for the install to finish (about 10 minutes):
   ```
   ssh -i ~/.ssh/swiggy-key.pem ubuntu@<public_ip>
   tail -f /var/log/cloud-init-output.log   # wait for SETUP FINISHED
   ```
5. Configure Jenkins (`http://<public_ip>:8080`) and SonarQube (`http://<public_ip>:9000`):
   - Jenkins plugins: Eclipse Temurin Installer, NodeJS, SonarQube Scanner, Docker Pipeline, Git
   - Tools (names must match the Jenkinsfile): `jdk17`, `node23`, `sonar-scanner`
   - Credentials: `Sonar-token` (Secret text), `docker-creds` (DockerHub username + access token)
   - SonarQube server in Jenkins: name `sonar-server`, URL `http://localhost:9000`
   - SonarQube webhook URL: `http://172.17.0.1:8080/sonarqube-webhook/`
6. Create a Pipeline job, paste the `Jenkinsfile` (set `DOCKER_USER` to your DockerHub username), and click **Build Now**. The app runs at `http://<public_ip>:3000`.

## Problems I hit and how I fixed them

The original tutorial is a few years old, so several steps needed changes:

| Problem | Cause | Fix |
|---|---|---|
| Jenkins would not install | The apt repository signing key used in the tutorial (2023) has expired | Use `jenkins.io-2026.key` |
| Jenkins service exited immediately after starting | Startup failure with the Java 17 install | Installed Temurin 21 for the Jenkins service, then reset and restarted it |
| SonarQube container kept exiting | Kernel `vm.max_map_count` too low for its embedded search engine | `sysctl -w vm.max_map_count=524288`, saved in `/etc/sysctl.conf` |
| Sonar stage: `HTTP connect timed out` | Jenkins called SonarQube through the server's public IP, which the security group blocks | Use `http://localhost:9000` in Jenkins; webhook uses the Docker bridge address `172.17.0.1` |
| `npm install`: `libatomic.so.1` not found | Fresh Ubuntu image lacks the library Node needs | `apt-get install libatomic1` |
| Docker login failed: client version too old | Jenkins' "docker" tool downloads a very old Docker client | Removed `toolName` from `withDockerRegistry` to use the server's own Docker |
| Pipeline syntax error at the OWASP stage | A `/* */` comment ended early because `**/` contains `*/` | Disabled the stage with `when { expression { return false } }` instead |
| Rerunning the pipeline failed | Container name `swiggy` already in use | Added `docker rm -f swiggy \|\| true` before `docker run` |
| SSH `Connection timed out` | Public IP changed, so the security group no longer matched | Update `my_ip` in `terraform.tfvars` and re-apply |
| SSH `Identity file not accessible` | Key file path / key pair mismatch | Use the full path `~/.ssh/<key>.pem`; a lost key cannot be recovered, so create a new key pair and replace the instance |

## Cost and cleanup

The project runs on AWS Free plan credits. Run it in one or two sittings, then remove everything:

```
terraform destroy
aws ec2 delete-key-pair --key-name swiggy-key --region ap-south-1
```

Check the EC2 console (Mumbai) for leftover instances and volumes, delete the IAM access key and the DockerHub access token you created, and do not leave the server running.

## Security notes

- The security group allows ports 22, 3000, 8080 and 9000 from **one IP only**. Never open Jenkins or SonarQube to `0.0.0.0/0`.
- Never commit `.pem` files, `terraform.tfstate`, `terraform.tfvars` or AWS credentials.
- Use DockerHub access tokens, not your account password, in Jenkins.
- Change the default SonarQube `admin` password on first login.

## .gitignore

```
*.pem
*.tfstate
*.tfstate.*
.terraform/
terraform.tfvars
.terraform.lock.hcl
```
