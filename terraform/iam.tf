############################################
# EC2 instance role
# Scoped to: SSM (for remote access instead of
# SSH), CloudWatch logs/metrics, and read/write
# to ONE specific S3 bucket (not full account access)
############################################
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_role" {
  name               = "${var.project_name}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ec2_cloudwatch" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Scoped S3 access instead of AmazonS3FullAccess
data "aws_iam_policy_document" "ec2_s3_scoped" {
  statement {
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket",
    ]
    resources = [
      aws_s3_bucket.app_bucket.arn,
      "${aws_s3_bucket.app_bucket.arn}/*",
    ]
  }
}

resource "aws_iam_role_policy" "ec2_s3_scoped" {
  name   = "${var.project_name}-ec2-s3-scoped"
  role   = aws_iam_role.ec2_role.id
  policy = data.aws_iam_policy_document.ec2_s3_scoped.json
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

############################################
# Lambda execution role (for the cleanup function)
# Scoped to exactly the EC2 actions it needs,
# not EC2FullAccess
############################################
data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_cleanup_role" {
  name               = "${var.project_name}-lambda-cleanup-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "lambda_basic_logs" {
  role       = aws_iam_role.lambda_cleanup_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "lambda_ec2_scoped" {
  statement {
    actions = [
      "ec2:DescribeInstances",
      "ec2:StopInstances",
      "ec2:TerminateInstances",
    ]
    resources = ["*"] # EC2 describe/stop/terminate don't support resource-level scoping cleanly;
    # tighten further with a Condition on tags in production, e.g. aws:ResourceTag/Project
  }
}

resource "aws_iam_role_policy" "lambda_ec2_scoped" {
  name   = "${var.project_name}-lambda-ec2-scoped"
  role   = aws_iam_role.lambda_cleanup_role.id
  policy = data.aws_iam_policy_document.lambda_ec2_scoped.json
}

############################################
# ECS Task Execution role (lets Fargate pull
# images from ECR and write logs)
############################################
data "aws_iam_policy_document" "ecs_task_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "${var.project_name}-ecs-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume.json
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Separate task role for the app itself (permissions your
# app code needs at runtime, e.g. reading from the same S3 bucket)
resource "aws_iam_role" "ecs_task_role" {
  name               = "${var.project_name}-ecs-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume.json
}

resource "aws_iam_role_policy" "ecs_task_s3_scoped" {
  name   = "${var.project_name}-ecs-task-s3-scoped"
  role   = aws_iam_role.ecs_task_role.id
  policy = data.aws_iam_policy_document.ec2_s3_scoped.json
}
