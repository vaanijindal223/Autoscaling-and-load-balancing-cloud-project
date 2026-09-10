############################################
# Application Load Balancer (public-facing)
############################################
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  tags = {
    Name = "${var.project_name}-alb"
  }
}

############################################
# Target Group - EC2 backend
# type = "instance" because the ASG registers
# EC2 instance IDs directly
############################################
resource "aws_lb_target_group" "backend_ec2" {
  name        = "${var.project_name}-tg-ec2"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"

  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 15
    timeout             = 5
    matcher             = "200"
  }

  tags = {
    Name = "${var.project_name}-tg-ec2"
  }
}

############################################
# Target Group - ECS/Fargate backend
# type = "ip" because Fargate tasks get their
# own ENI/IP, not an instance ID
############################################
resource "aws_lb_target_group" "backend_ecs" {
  name        = "${var.project_name}-tg-ecs"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 15
    timeout             = 5
    matcher             = "200"
  }

  tags = {
    Name = "${var.project_name}-tg-ecs"
  }
}

############################################
# Listener - port 80 -> EC2 target group
############################################
resource "aws_lb_listener" "http_ec2" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_ec2.arn
  }
}

############################################
# Listener - port 8080 -> ECS target group
# Two separate ports instead of path-based
# routing: keeps the app itself unaware of
# which backend served it, and avoids the ALB
# forwarding a path prefix (e.g. /v2/health)
# that the Flask app doesn't actually have a
# route for.
############################################
resource "aws_lb_listener" "http_ecs" {
  load_balancer_arn = aws_lb.main.arn
  port              = 8080
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_ecs.arn
  }
}

############################################
# Attach the ASG to the EC2 target group
############################################
resource "aws_autoscaling_attachment" "backend_ec2_attachment" {
  autoscaling_group_name = aws_autoscaling_group.backend.name
  lb_target_group_arn    = aws_lb_target_group.backend_ec2.arn
}