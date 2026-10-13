resource "aws_vpc" "trend_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "trend-vpc"
  }
}
resource "aws_subnet" "trend_subnet" {
  vpc_id                  = aws_vpc.trend_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "trend-subnet"
  }
}
resource "aws_subnet" "trend_eks_subnet_b" {
  vpc_id                  = aws_vpc.trend_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "ap-south-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "trend-eks-subnet-b"
  }
}

resource "aws_subnet" "trend_eks_subnet_c" {
  vpc_id                  = aws_vpc.trend_vpc.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "ap-south-1c"
  map_public_ip_on_launch = true

  tags = {
    Name = "trend-eks-subnet-c"
  }
}
resource "aws_internet_gateway" "trend_igw" {
  vpc_id = aws_vpc.trend_vpc.id

  tags = {
    Name = "trend-igw"
  }
}
resource "aws_route_table" "trend_route_table" {
  vpc_id = aws_vpc.trend_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.trend_igw.id
  }

  tags = {
    Name = "trend-route-table"
  }
}
resource "aws_route_table_association" "trend_subnet_association" {
  subnet_id      = aws_subnet.trend_subnet.id
  route_table_id = aws_route_table.trend_route_table.id
}
resource "aws_route_table_association" "trend_eks_subnet_b_association" {
  subnet_id      = aws_subnet.trend_eks_subnet_b.id
  route_table_id = aws_route_table.trend_route_table.id
}

resource "aws_route_table_association" "trend_eks_subnet_c_association" {
  subnet_id      = aws_subnet.trend_eks_subnet_c.id
  route_table_id = aws_route_table.trend_route_table.id
}
resource "aws_security_group" "trend_ec2_sg" {
  name        = "trend-ec2-sg"
  description = "Security group for Trend EC2"
  vpc_id      = aws_vpc.trend_vpc.id

  # SSH - only from my computer
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"

    cidr_blocks = [var.admin_cidr]
  }

  # Jenkins - only from my computer
  ingress {
    description = "Jenkins"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"

    cidr_blocks = [var.admin_cidr]
  }

  # React application - only from my computer for now
  ingress {
    description = "React application"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"

    cidr_blocks = [var.admin_cidr]
  }

  # GitHub webhooks - allow GitHub IPv4 ranges to reach Jenkins
  ingress {
    description = "GitHub webhooks"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"

    cidr_blocks = [
      "9.234.106.48/28",
      "9.234.98.160/28",
      "9.234.98.176/28",
      "192.30.252.0/22",
      "185.199.108.0/22",
      "140.82.112.0/20",
      "143.55.64.0/20",
    ]
  }

  # HTTP - public
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"

    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow EC2 to make outbound connections
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "trend-ec2-sg"
  }
}
resource "aws_iam_role" "trend_ec2_role" {
  name = "trend-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "trend-ec2-role"
  }
}
resource "aws_eks_cluster" "trend_eks" {
  name     = "trend-eks"
  role_arn = aws_iam_role.trend_eks_cluster_role.arn

  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
  }

  vpc_config {
    subnet_ids = [
      aws_subnet.trend_eks_subnet_b.id,
      aws_subnet.trend_eks_subnet_c.id
    ]

    endpoint_public_access  = true
    endpoint_private_access = true
    public_access_cidrs     = [var.admin_cidr]

  }

  depends_on = [
    aws_iam_role_policy_attachment.trend_eks_cluster_policy
  ]

  tags = {
    Name = "trend-eks"
  }
}
resource "aws_iam_instance_profile" "trend_ec2_profile" {
  name = "trend-ec2-profile"
  role = aws_iam_role.trend_ec2_role.name
}
data "aws_ami" "ubuntu" {
  most_recent = true

  owners = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}
resource "aws_instance" "trend_ec2" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.small"

  subnet_id = aws_subnet.trend_subnet.id

  vpc_security_group_ids = [
    aws_security_group.trend_ec2_sg.id
  ]

  key_name = var.key_name

  iam_instance_profile = aws_iam_instance_profile.trend_ec2_profile.name

  associate_public_ip_address = true

  user_data = <<-EOF
  #!/bin/bash

  set -e

  # Update Ubuntu
  apt-get update -y
  apt-get upgrade -y

  # Install Java
  apt-get install -y fontconfig openjdk-21-jre

  # Install Docker
  apt-get install -y docker.io

  systemctl enable docker
  systemctl start docker

  # Install Jenkins
  curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key \
    -o /usr/share/keyrings/jenkins-keyring.asc

  echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" \
    > /etc/apt/sources.list.d/jenkins.list

  apt-get update -y
  apt-get install -y jenkins

  apt-get install -y unzip curl
  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
  unzip -q /tmp/awscliv2.zip -d /tmp
  /tmp/aws/install
  rm -rf /tmp/aws /tmp/awscliv2.zip

  curl -fsSL -o /usr/local/bin/kubectl "https://dl.k8s.io/release/v1.36.4/bin/linux/amd64/kubectl"
  chmod +x /usr/local/bin/kubectl


  # Allow Jenkins to use Docker
  usermod -aG docker jenkins

  # Start Jenkins
  systemctl enable jenkins
  systemctl start jenkins
EOF

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name = "trend-ec2"
  }
}
# =========================
# EKS IAM - Cluster Role
# =========================

resource "aws_iam_role" "trend_eks_cluster_role" {
  name = "trend-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "eks.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "trend-eks-cluster-role"
  }
}

resource "aws_iam_role_policy_attachment" "trend_eks_cluster_policy" {
  role       = aws_iam_role.trend_eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}


# =========================
# EKS IAM - Node Role
# =========================

resource "aws_iam_role" "trend_eks_node_role" {
  name = "trend-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "trend-eks-node-role"
  }
}

resource "aws_iam_role_policy_attachment" "trend_eks_worker_node_policy" {
  role       = aws_iam_role.trend_eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "trend_eks_cni_policy" {
  role       = aws_iam_role.trend_eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "trend_eks_ecr_read_only_policy" {
  role       = aws_iam_role.trend_eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}
# =========================
# EKS Managed Node Group
# =========================

resource "aws_eks_node_group" "trend_eks_nodes" {
  cluster_name    = aws_eks_cluster.trend_eks.name
  node_group_name = "trend-eks-node-group"
  node_role_arn   = aws_iam_role.trend_eks_node_role.arn

  subnet_ids = [
    aws_subnet.trend_eks_subnet_b.id,
    aws_subnet.trend_eks_subnet_c.id
  ]

  instance_types = ["t3.small"]

  scaling_config {
    desired_size = 2
    max_size     = 2
    min_size     = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.trend_eks_worker_node_policy,
    aws_iam_role_policy_attachment.trend_eks_cni_policy,
    aws_iam_role_policy_attachment.trend_eks_ecr_read_only_policy
  ]

  tags = {
    Name = "trend-eks-node-group"
  }
}
resource "aws_iam_role_policy" "trend_ec2_eks_access" {
  name = "trend-ec2-eks-access"
  role = aws_iam_role.trend_ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster"
        ]
        Resource = aws_eks_cluster.trend_eks.arn
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage",
          "ecr:BatchGetImage"
        ]
        Resource = "arn:aws:ecr:ap-south-1:074478994008:repository/trend-application"
      }
    ]
  })
}

# Allow the Jenkins EC2 role to authenticate to EKS
resource "aws_eks_access_entry" "jenkins" {
  cluster_name  = aws_eks_cluster.trend_eks.name
  principal_arn = aws_iam_role.trend_ec2_role.arn
  type          = "STANDARD"
}

# Allow Jenkins to manage application resources in the default namespace
resource "aws_eks_access_policy_association" "jenkins_edit" {
  cluster_name  = aws_eks_cluster.trend_eks.name
  principal_arn = aws_iam_role.trend_ec2_role.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"

  access_scope {
    type       = "namespace"
    namespaces = ["default"]
  }

  depends_on = [
    aws_eks_access_entry.jenkins
  ]
}
