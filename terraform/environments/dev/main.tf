# =============================================================================
# AI-Driven IaC Workshop - Development Environment
# =============================================================================

terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend configuration (uncomment for remote state)
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "${var.participant_id}/dev/terraform.tfstate"
  #   region         = "ap-northeast-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-lock"
  # }
}

# -----------------------------------------------------------------------------
# Provider Configuration
# -----------------------------------------------------------------------------

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment   = "dev"
      Project       = var.project_name
      ParticipantId = var.participant_id
      ManagedBy     = "terraform"
    }
  }
}

# -----------------------------------------------------------------------------
# Variables
# -----------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "iac-workshop"
}

variable "participant_id" {
  description = "Unique identifier for each workshop participant (e.g., user01, tanaka)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{3,15}$", var.participant_id))
    error_message = "participant_id must be 3-15 characters, lowercase alphanumeric and hyphens only."
  }
}

# -----------------------------------------------------------------------------
# Local Variables
# -----------------------------------------------------------------------------

locals {
  # Include participant_id in resource naming
  name_prefix = "${var.project_name}-${var.participant_id}"
  
  # Calculate unique VPC CIDR based on participant_id hash (to avoid conflicts)
  # This creates CIDRs like 10.1.0.0/16, 10.2.0.0/16, etc.
  participant_hash = abs(tonumber(format("%d", parseint(substr(md5(var.participant_id), 0, 4), 16)))) % 250 + 1
  vpc_cidr         = "10.${local.participant_hash}.0.0/16"
}

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------

output "aws_account_id" {
  description = "AWS Account ID"
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "AWS Region"
  value       = var.aws_region
}

# -----------------------------------------------------------------------------
# Outputs - Participant Info
# -----------------------------------------------------------------------------

output "participant_id" {
  description = "Participant ID"
  value       = var.participant_id
}

output "name_prefix" {
  description = "Resource name prefix"
  value       = local.name_prefix
}

output "vpc_cidr" {
  description = "VPC CIDR (auto-calculated from participant_id)"
  value       = local.vpc_cidr
}

# -----------------------------------------------------------------------------
# Resources (Add your resources here)
# -----------------------------------------------------------------------------

# Example: VPC (Uncomment to use)
# module "vpc" {
#   source = "../../modules/vpc"
#
#   project_name   = var.project_name
#   participant_id = var.participant_id
#   environment    = "dev"
#   vpc_cidr       = local.vpc_cidr
# }

