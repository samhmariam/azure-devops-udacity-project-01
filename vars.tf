variable "azure-subscription-id" {
  type        = string
  description = "Azure Subscription ID"
}

variable "azure-client-id" {
  type        = string
  description = "Azure Client ID"
}

variable "azure-client-secret" {
  type        = string
  description = "Azure Client Secret"
}

variable "azure-tenant-id" {
  type        = string
  description = "Azure Tenant ID"
}



variable "prefix" {
  description = "The prefix which should be used for all resources in the resource group specified"
  default     = "udacity-devops-proj-01"
  type        = string
}

variable "username" {
  type        = string
  description = "VM admin User"
  default     = "shewit_su"
}

# VM Admin Password
variable "password" {
  type        = string
  description = "VM admin Password"
  default     = "UdacityProj01"
}

variable "count_of_vms" {
  description = "Number of VM to create behind the load balancer"
  default     = 2
  type        = number
}

variable "vm_tag" {
    description = " VM tag with the project name"
    type        = string
    default     = "vm"
}

variable "nsg_tag" {
    description = " NSG tag"
    type        = string
    default     = "nsg"
}

variable "network_tag" {
    description = " Network tag"
    type        = string
    default     = "network"
}

variable "lb_tag" {
    description = " LB tag"
    type        = string
    default     = "lb"
}

variable "avset_tag" {
    description = " LB tag"
    type        = string
    default     = "avset"
}