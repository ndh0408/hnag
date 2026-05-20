variable "project" {
  type    = string
  default = "hnag"
}

variable "environment" {
  type        = string
  description = "production | staging | dev"
  validation {
    condition     = contains(["production", "staging", "dev"], var.environment)
    error_message = "Environment must be production, staging, or dev."
  }
}

variable "region" {
  type    = string
  default = "ap-southeast-1"
}

variable "api_node_min"     { type = number, default = 3 }
variable "api_node_max"     { type = number, default = 30 }
variable "api_node_desired" { type = number, default = 6 }

variable "rds_instance_class" {
  type    = string
  default = "db.r6g.large"
}

variable "rds_storage_gb" {
  type    = number
  default = 200
}

variable "rds_master_password" {
  type      = string
  sensitive = true
}

variable "redis_node_type" {
  type    = string
  default = "cache.r6g.large"
}

variable "redis_auth_token" {
  type      = string
  sensitive = true
}
