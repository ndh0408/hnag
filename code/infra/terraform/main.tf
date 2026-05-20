# =============================================================================
# HNAG — AWS infrastructure (Terraform)
# Region: ap-southeast-1 (Singapore) — best for Vietnam latency
# =============================================================================

terraform {
  required_version = ">= 1.6"
  required_providers {
    aws        = { source = "hashicorp/aws", version = "~> 5.50" }
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.30" }
    helm       = { source = "hashicorp/helm", version = "~> 2.13" }
  }

  backend "s3" {
    bucket         = "hnag-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "ap-southeast-1"
    dynamodb_table = "hnag-terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Project     = "hnag"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# =============================================================================
# VPC
# =============================================================================
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.8"

  name = "${var.project}-${var.environment}"
  cidr = "10.0.0.0/16"

  azs              = ["${var.region}a", "${var.region}b", "${var.region}c"]
  private_subnets  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets   = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  database_subnets = ["10.0.201.0/24", "10.0.202.0/24", "10.0.203.0/24"]

  enable_nat_gateway     = true
  single_nat_gateway     = var.environment != "production"
  enable_dns_hostnames   = true
  enable_dns_support     = true
  enable_flow_log        = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }
}

# =============================================================================
# EKS
# =============================================================================
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.20"

  cluster_name    = "${var.project}-${var.environment}"
  cluster_version = "1.30"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  cluster_addons = {
    coredns                = { most_recent = true }
    kube-proxy             = { most_recent = true }
    vpc-cni                = { most_recent = true }
    aws-ebs-csi-driver     = { most_recent = true }
  }

  eks_managed_node_groups = {
    api = {
      instance_types = ["t3.large"]
      min_size       = var.api_node_min
      max_size       = var.api_node_max
      desired_size   = var.api_node_desired
      labels         = { workload = "api" }
    }
    workers = {
      instance_types = ["c6i.xlarge"]
      min_size       = 1
      max_size       = 12
      desired_size   = 2
      labels         = { workload = "background" }
      taints = [{ key = "workload", value = "background", effect = "NO_SCHEDULE" }]
    }
    ai = {
      instance_types = ["g4dn.xlarge"]  # GPU for self-hosted Whisper
      min_size       = 0
      max_size       = 4
      desired_size   = var.environment == "production" ? 1 : 0
      labels         = { workload = "ai-gpu" }
      taints = [{ key = "nvidia.com/gpu", value = "true", effect = "NO_SCHEDULE" }]
    }
  }
}

# =============================================================================
# RDS (PostgreSQL + PostGIS, Multi-AZ in prod)
# =============================================================================
resource "aws_db_subnet_group" "main" {
  name       = "${var.project}-${var.environment}"
  subnet_ids = module.vpc.database_subnets
}

resource "aws_security_group" "rds" {
  name   = "${var.project}-${var.environment}-rds"
  vpc_id = module.vpc.vpc_id
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    cidr_blocks     = [module.vpc.vpc_cidr_block]
  }
  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "main" {
  identifier             = "${var.project}-${var.environment}"
  engine                 = "postgres"
  engine_version         = "15.7"
  instance_class         = var.rds_instance_class
  allocated_storage      = var.rds_storage_gb
  max_allocated_storage  = var.rds_storage_gb * 4
  storage_type           = "gp3"
  storage_encrypted      = true
  db_name                = "hnag"
  username               = "hnag"
  password               = var.rds_master_password
  port                   = 5432
  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name
  multi_az               = var.environment == "production"
  backup_retention_period = 14
  backup_window          = "17:00-18:00"          # UTC, ~midnight VN
  maintenance_window     = "Mon:18:30-Mon:19:30"
  deletion_protection    = var.environment == "production"
  skip_final_snapshot    = var.environment != "production"
  final_snapshot_identifier = "${var.project}-${var.environment}-final-${formatdate("YYYYMMDD", timestamp())}"
  parameter_group_name   = aws_db_parameter_group.main.name
  performance_insights_enabled = true
  monitoring_interval    = 60
  monitoring_role_arn    = aws_iam_role.rds_monitoring.arn
}

resource "aws_db_parameter_group" "main" {
  name   = "${var.project}-${var.environment}-pg15"
  family = "postgres15"
  parameter { name = "shared_preload_libraries"; value = "pg_stat_statements"; apply_method = "pending-reboot" }
  parameter { name = "log_min_duration_statement"; value = "500" }
  parameter { name = "log_statement"; value = "ddl" }
}

resource "aws_iam_role" "rds_monitoring" {
  name = "${var.project}-${var.environment}-rds-monitoring"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "monitoring.rds.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# Read replica for analytics (prod only)
resource "aws_db_instance" "replica" {
  count                   = var.environment == "production" ? 1 : 0
  identifier              = "${var.project}-${var.environment}-ro"
  replicate_source_db     = aws_db_instance.main.identifier
  instance_class          = var.rds_instance_class
  skip_final_snapshot     = true
  vpc_security_group_ids  = [aws_security_group.rds.id]
}

# =============================================================================
# ElastiCache Redis
# =============================================================================
resource "aws_elasticache_subnet_group" "main" {
  name       = "${var.project}-${var.environment}"
  subnet_ids = module.vpc.private_subnets
}

resource "aws_security_group" "redis" {
  name   = "${var.project}-${var.environment}-redis"
  vpc_id = module.vpc.vpc_id
  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }
}

resource "aws_elasticache_replication_group" "main" {
  replication_group_id       = "${var.project}-${var.environment}"
  description                = "HNAG Redis cluster"
  engine                     = "redis"
  engine_version             = "7.1"
  node_type                  = var.redis_node_type
  num_node_groups            = var.environment == "production" ? 3 : 1
  replicas_per_node_group    = var.environment == "production" ? 1 : 0
  parameter_group_name       = "default.redis7.cluster.on"
  port                       = 6379
  subnet_group_name          = aws_elasticache_subnet_group.main.name
  security_group_ids         = [aws_security_group.redis.id]
  automatic_failover_enabled = var.environment == "production"
  multi_az_enabled           = var.environment == "production"
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                 = var.redis_auth_token
  snapshot_retention_limit   = 7
  apply_immediately          = false
}

# =============================================================================
# S3 buckets
# =============================================================================
resource "aws_s3_bucket" "media" {
  bucket = "${var.project}-media-${var.environment}"
}

resource "aws_s3_bucket_versioning" "media" {
  bucket = aws_s3_bucket.media.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "media" {
  bucket = aws_s3_bucket.media.id
  rule { apply_server_side_encryption_by_default { sse_algorithm = "AES256" } }
}

resource "aws_s3_bucket_lifecycle_configuration" "media" {
  bucket = aws_s3_bucket.media.id
  rule {
    id     = "archive-old-videos"
    status = "Enabled"
    filter { prefix = "raw-uploads/" }
    transition { days = 30 storage_class = "STANDARD_IA" }
    transition { days = 90 storage_class = "GLACIER" }
  }
}

resource "aws_s3_bucket_cors_configuration" "media" {
  bucket = aws_s3_bucket.media.id
  cors_rule {
    allowed_methods = ["GET", "PUT", "POST", "HEAD"]
    allowed_origins = ["https://tothanhthuy.cloud", "https://*.tothanhthuy.cloud"]
    allowed_headers = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket" "data_lake" {
  bucket = "${var.project}-datalake-${var.environment}"
}

resource "aws_s3_bucket" "backups" {
  bucket = "${var.project}-backups-${var.environment}"
}

# =============================================================================
# CloudFront for CDN
# =============================================================================
resource "aws_cloudfront_distribution" "cdn" {
  enabled         = true
  comment         = "${var.project}-${var.environment} media CDN"
  default_root_object = ""
  price_class     = "PriceClass_200"  # incl. SEA

  origin {
    domain_name = aws_s3_bucket.media.bucket_regional_domain_name
    origin_id   = "s3-media"
    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.media.cloudfront_access_identity_path
    }
  }

  default_cache_behavior {
    target_origin_id       = "s3-media"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    forwarded_values {
      query_string = true
      cookies { forward = "none" }
      headers = ["Origin"]
    }
  }

  restrictions { geo_restriction { restriction_type = "none" } }
  viewer_certificate { cloudfront_default_certificate = true }
}

resource "aws_cloudfront_origin_access_identity" "media" {
  comment = "HNAG media OAI"
}

# =============================================================================
# ECR
# =============================================================================
resource "aws_ecr_repository" "backend" {
  name                 = "hnag-backend"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration { scan_on_push = true }
  encryption_configuration { encryption_type = "AES256" }
}

resource "aws_ecr_lifecycle_policy" "backend" {
  repository = aws_ecr_repository.backend.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 30 images"
      selection = {
        tagStatus     = "any"
        countType     = "imageCountMoreThan"
        countNumber   = 30
      }
      action = { type = "expire" }
    }]
  })
}

resource "aws_ecr_repository" "dashboard" {
  name                 = "hnag-owner-dashboard"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration { scan_on_push = true }
}

# =============================================================================
# Outputs
# =============================================================================
output "vpc_id"        { value = module.vpc.vpc_id }
output "eks_cluster"   { value = module.eks.cluster_name }
output "rds_endpoint"  { value = aws_db_instance.main.address sensitive = true }
output "redis_endpoint"{ value = aws_elasticache_replication_group.main.primary_endpoint_address sensitive = true }
output "ecr_backend"   { value = aws_ecr_repository.backend.repository_url }
output "cdn_domain"    { value = aws_cloudfront_distribution.cdn.domain_name }
output "media_bucket"  { value = aws_s3_bucket.media.id }
