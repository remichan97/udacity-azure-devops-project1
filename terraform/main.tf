terraform {
  required_providers {
    random = {
      source = "hashicorp/random"
    }
  }
}

provider "azurerm" {
  features {}
}

data "azurerm_image" "packer_image" {
  name                = var.packer-image-name
  resource_group_name = var.rg
}

resource "tls_private_key" "vm_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

data "azurerm_resource_group" "main" {
  name = var.rg
}

resource "azurerm_virtual_network" "main" {
  name                = "${data.azurerm_resource_group.main.name}-network"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name

  tags = {
    userTaggedValue = var.tag_name
  }
}

resource "azurerm_subnet" "internal" {
  name                 = "internal"
  resource_group_name  = data.azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "public_ip" {
  name                = "vmss-public-ip"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name
  allocation_method   = "Static"
  tags = {
    userTaggedValue = var.tag_name
  }
}

resource "azurerm_lb" "project_lb" {
  name                = "${data.azurerm_resource_group.main.name}-lb"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = var.location

  frontend_ip_configuration {
    name                 = "PublicIpAddress"
    public_ip_address_id = azurerm_public_ip.public_ip.id
  }
  tags = {
    userTaggedValue = var.tag_name
  }
}

resource "azurerm_network_security_group" "vmss-nsg" {
  location            = var.location
  name                = "${data.azurerm_resource_group.main.name}-nsg"
  resource_group_name = data.azurerm_resource_group.main.name
  tags = {
    userTaggedValue = var.tag_name
  }
}

resource "azurerm_network_interface" "vmas_nic" {
  count               = var.vm_count
  name                = "${data.azurerm_resource_group.main.name}-nic-${count.index}"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name
  ip_configuration {
    name                          = "vmas-nic"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
  }
  tags = {
    userTaggedValue = var.tag_name
  }
}

resource "azurerm_network_security_rule" "vmss_deny_from_internet" {
  resource_group_name         = data.azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.vmss-nsg.name
  priority                    = 200
  source_address_prefix       = "Internet"
  destination_address_prefix  = "Internet"
  direction                   = "Inbound"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  access                      = "Deny"
  name                        = "DenyDirectAccessFromInternet"
}

resource "azurerm_network_security_rule" "vmss_allow_access_to_other_vms" {
  resource_group_name         = data.azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.vmss-nsg.name
  priority                    = 150
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "VirtualNetwork"
  direction                   = "Inbound"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  access                      = "Allow"
  name                        = "AllowAccessToOtherVMs"
}

resource "azurerm_lb_backend_address_pool" "bpaddresspool" {
  name            = "${data.azurerm_resource_group.main.name}-bpapool"
  loadbalancer_id = azurerm_lb.project_lb.id
}

resource "azurerm_lb_probe" "vmss_probee" {
  name            = "${data.azurerm_resource_group.main.name}-probe"
  loadbalancer_id = azurerm_lb.project_lb.id
  port            = 80
}

resource "azurerm_lb_rule" "vmss_lb_rule" {
  loadbalancer_id                = azurerm_lb.project_lb.id
  name                           = "${data.azurerm_resource_group.main.name}-lbrule"
  backend_port                   = "5000"
  frontend_port                  = 80
  protocol                       = "Tcp"
  frontend_ip_configuration_name = "PublicIpAddress"
}

resource "azurerm_availability_set" "vmas" {
  location            = var.location
  name                = "${data.azurerm_resource_group.main.name}-vmas"
  resource_group_name = data.azurerm_resource_group.main.name
  tags = {
    userTaggedValue = var.tag_name
  }
}

resource "azurerm_linux_virtual_machine" "vmas_vm_instances" {
  count                 = var.vm_count
  name                  = "${data.azurerm_resource_group.main.name}-vm-${count.index}"
  resource_group_name   = data.azurerm_resource_group.main.name
  location              = var.location
  size                  = "Standard_B2s"
  admin_username        = var.username
  source_image_id       = "/subscriptions/${var.subscription_id}/resourceGroups/${var.rg}/providers/Microsoft.Compute/images/packer-images"
  availability_set_id   = azurerm_availability_set.vmas.id
  network_interface_ids = [azurerm_network_interface.vmas_nic.*.id[count.index]]

  admin_ssh_key {
    username   = var.username
    public_key = tls_private_key.vm_ssh.public_key_openssh
  }

  os_disk {
    disk_size_gb         = 30
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }


  tags = {
    userTaggedValue = var.tag_name
  }
}

output "ssh_private_key" {
  description = "The newly created SSH Private key. Please save the output to a .pem file"
  value       = tls_private_key.vm_ssh.private_key_openssh
  sensitive   = false
}
