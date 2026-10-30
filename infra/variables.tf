variable "region" {
  description = "AWS region for the instance, the artifacts bucket and SES."
  type        = string
  default     = "eu-central-1"
}

variable "aws_profile" {
  description = "Local AWS CLI profile Terraform uses (needs admin-level rights, NOT the SES-only 'portfolio' profile)."
  type        = string
  default     = "portfolio-admin"
}

variable "domain" {
  description = "Apex domain. Its Route 53 hosted zone already exists and is only read here."
  type        = string
  default     = "shiroyasha.dev"
}

variable "instance_type" {
  description = "t4g.micro (1 GB RAM) is comfortable; t4g.nano (0.5 GB) is about half the price."
  type        = string
  default     = "t4g.micro"
}

variable "root_volume_gb" {
  description = "Root disk size. 8 GB is the minimum for the Amazon Linux 2023 image."
  type        = number
  default     = 8
}

variable "contact_from" {
  description = "Sender address for contact-form mail. Must be on the SES-verified domain."
  type        = string
  default     = "contact@shiroyasha.dev"
}

variable "contact_to" {
  description = "Inbox that receives contact-form messages."
  type        = string
  default     = "balidavid@shiroyasha.dev"
}

variable "acme_email" {
  description = "Email Let's Encrypt uses for certificate expiry warnings."
  type        = string
  default     = "hello@shiroyasha.dev"
}

variable "caddy_version" {
  description = "Caddy release installed on the server (github.com/caddyserver/caddy/releases)."
  type        = string
  default     = "2.10.2"
}
