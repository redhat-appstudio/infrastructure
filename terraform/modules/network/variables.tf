variable "private_subnets" {
  description = "A list of private subnets inside the VPC"
  type        = list(string)
  default     = []
}

variable "public_subnets" {
  description = "A list of public subnets inside the VPC"
  type        = list(string)
  default     = []
}

variable "vpc_cidr" {
  type    = string
  default = null
}

variable "cluster_name" {
  type    = string
  default = null
}

variable "transit_gateway_id" {
  type    = string
  default = null
}

variable "network_firewall_required" {
  type    = string
  default = null
}
