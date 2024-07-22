variable "token" {
  type      = string
  sensitive = true
  default   = null
}

variable "url" {
  type        = string
  description = "Provide OCM environment by setting a value to url"
  default     = "https://api.openshift.com"
}

variable "managed" {
  description = "Indicates whether it is a Red Hat managed or unmanaged (Customer hosted) OIDC Configuration"
  type        = bool
  default     = true
}

variable "installer_role_arn" {
  description = "STS Role ARN with get secrets permission, relevant only for unmanaged OIDC config"
  type        = string
  default     = null
}

variable "account_role_prefix" {
  description = "(Mandatory) Terraform Automation does not yet support auto generated option for crerating account roles"
  type        = string
  default     = "ManagedOpenShift"
}

variable "operator_role_prefix" {
  description = "(Mandatory) Terraform Automation does not yet support auto generated option for crerating operator roles"
  type        = string
  default     = "ManagedOpenShift"
}

variable "cloud_region" {
  type    = string
  default = "us-east-1"
}

variable "tags" {
  description = "List of AWS resource tags to apply."
  type        = map(string)
  default     = null
}

variable "path" {
  description = "(Optional) The arn path for the account/operator roles as well as their policies."
  type        = string
  default     = null
}
