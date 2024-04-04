variable "rg" {
  description = "The resource group name, this will also be used as prefix appending to the newly created resourses name."
  type = string
  default = "udacity-devops"
}

variable "tag_name" {
  description = "This is the tag name assigned to the newly created resources"
  type = string
  default = "udacity"
}

variable "location" {
  description = "Where should we create the resources"
  type = string
  default = "East US"
}

variable "username" {
  description = "The username for the VM being created."
  type = string
  default = "mirai"
}

variable "vm_count" {
  description = "The amount of VMs should be created, a maximum of 5 and a minimum instance of 2 is allowed"
  type = number
  validation {
    error_message = "The value must be between 2 and 5"
    condition = var.vm_count >= 2 && var.vm_count < 5
  }
  default = 2
}

variable "subscription_id" {
  description = "The Subscription ID of the Azure Subscription."
  type = string
  default = "value"
}

variable "packer-image-name" {
  description = "The packer image name we generated eariler"
  type = string
  default = "packer-images"
}
