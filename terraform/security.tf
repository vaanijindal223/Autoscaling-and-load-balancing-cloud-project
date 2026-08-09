############################################
# ALB Security Group - only this one is open
# to the internet (80/443)
############################################
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Allow HTTP/HTTPS from internet"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-alb-sg"
  }
}

############################################
# App Security Group (EC2 + ECS tasks)
# Only accepts traffic from the ALB, not the
# open internet. SSH is only for your own
# testing - lock cidr_blocks down to your IP
# before demoing, don't leave it 0.0.0.0/0.
############################################
resource "aws_security_group" "app" {
  name        = "${var.project_name}-app-sg"
  description = "Allow traffic only from ALB, plus SSH for admin"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "App port from ALB only"
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description = "SSH for admin access - restrict to your IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    # IMPORTANT: this must include the /32 suffix - a CIDR block, not a bare IP.
    # Example: "103.212.138.246/32"  (NOT just "103.212.138.246")
    cidr_blocks = ["103.212.138.246/32"] # <-- replace YOUR_IP with your actual public IP, keep the /32
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-app-sg"
  }
}