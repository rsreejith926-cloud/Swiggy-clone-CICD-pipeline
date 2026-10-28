variable "my_ip" {
  description = "Your public IP in CIDR form, e.g. 203.0.113.5/32 (find it with: curl ifconfig.me)"
  type        = string
}

variable "key_name" {
  description = "Name of an existing EC2 key pair in ap-south-1"
  type        = string
  default     = "swiggy-key"
}

# Latest Ubuntu 22.04 AMI in the current region (replaces the hard-coded AMI)
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_security_group" "Project-SG" {
  name        = "Project-SG"
  description = "SSH, Jenkins, SonarQube, app - my IP only"

  ingress = [
    for port in [22, 8080, 9000, 3000] : {
      description      = "Allowed from my IP only"
      from_port        = port
      to_port          = port
      protocol         = "tcp"
      cidr_blocks      = [var.my_ip]
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
      self             = false
    }
  ]

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Project-SG"
  }
}

resource "aws_instance" "web" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "m7i-flex.large" # 8 GB, allowed on the Free plan
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.Project-SG.id]
  user_data              = templatefile("./resource.sh", {})

  tags = {
    Name = "swiggy-devops"
  }

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }
}

output "public_ip" {
  value = aws_instance.web.public_ip
}
