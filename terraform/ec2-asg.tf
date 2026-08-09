############################################
# Latest Amazon Linux 2023 AMI (auto-updates
# each apply - AWS publishes new AMIs regularly)
############################################
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

############################################
# User-data script: runs once on instance boot.
# Installs Docker + AWS CLI, logs into ECR,
# pulls the backend image, runs it as a container.
############################################
locals {
  backend_user_data = <<-EOF
    #!/bin/bash
    set -e

    # Install Docker
    dnf install -y docker unzip
    systemctl enable docker
    systemctl start docker

    # Install AWS CLI v2 (not preinstalled on base AL2023)
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip -q awscliv2.zip
    ./aws/install
    rm -rf awscliv2.zip aws/

    # Authenticate Docker to ECR using this instance's IAM role
    aws ecr get-login-password --region ${var.aws_region} | \
      docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com

    # Pull and run the backend container
    docker pull ${aws_ecr_repository.backend.repository_url}:latest

    docker run -d \
      --name backend \
      --restart unless-stopped \
      -p ${var.app_port}:${var.app_port} \
      -e DEPLOYMENT_TARGET=ec2-asg \
      -e APP_VERSION=1.0.0 \
      -e PORT=${var.app_port} \
      ${aws_ecr_repository.backend.repository_url}:latest
  EOF
}

############################################
# Launch Template
############################################
resource "aws_launch_template" "backend" {
  name_prefix   = "${var.project_name}-backend-lt-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"   "InstanceTypes[].InstanceType"
  # and use whatever it returns instead

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  vpc_security_group_ids = [aws_security_group.app.id]

  user_data = base64encode(local.backend_user_data)

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-backend-instance"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

############################################
# Auto Scaling Group
# NOTE: health_check_type is "EC2" for now (just
# checks the instance is running). In Phase 6, once
# the ALB + target group exist, we switch this to
# "ELB" so unhealthy app containers get replaced too,
# not just crashed instances.
############################################
resource "aws_autoscaling_group" "backend" {
  name                = "${var.project_name}-backend-asg"
  vpc_zone_identifier = aws_subnet.private[*].id

  min_size         = 1
  max_size         = 4
  desired_capacity = 2

  health_check_type        = "EC2"
  health_check_grace_period = 60

  launch_template {
    id      = aws_launch_template.backend.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-backend-asg-instance"
    propagate_at_launch = true
  }
}

############################################
# Target tracking scaling policy - keeps average
# CPU across the group near 50%. ASG adds/removes
# instances automatically to hold that target.
############################################
resource "aws_autoscaling_policy" "backend_cpu_target" {
  name                   = "${var.project_name}-backend-cpu-target-tracking"
  autoscaling_group_name = aws_autoscaling_group.backend.name
  policy_type             = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 50.0
  }
}