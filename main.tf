
provider "azurerm" {
  features {}
  subscription_id = var.azure-subscription-id
  client_id       = var.azure-client-id
  client_secret   = var.azure-client-secret
  tenant_id       = var.azure-tenant-id
}


resource "azurerm_resource_group" "main" {
  name     = "udacity-azure-devops-proj-01"
  location = "uksouth"
}


resource "azurerm_virtual_network" "main" {
  name                = "${var.prefix}-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_subnet" "main" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_network_security_group" "main" {
  name                = "${var.prefix}-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "AllowToSubnet"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "AllowFromSubnet"
    priority                   = 210
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "AllowHTTP"
    description                = "Allow HTTP access from load balancer to the Vms"
    priority                   = 220
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "DenyInternetAccess"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "Internet"
    destination_address_prefix = "VirtualNetwork" 
  }

   tags = {
    type = "${var.nsg_tag}"
  }
}

resource "azurerm_subnet_network_security_group_association" "example" {
  subnet_id                 = azurerm_subnet.main.id
  network_security_group_id = azurerm_network_security_group.main.id
}


resource "azurerm_network_interface" "main" {
  count               = var.count_of_vms
  name                = "${var.prefix}-nic${count.index}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Dynamic"
  }

   tags = {
    type = "${var.network_tag}"
  }
}

resource "azurerm_public_ip" "pip" {
  name                = "${var.prefix}-pip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
}


resource "azurerm_lb" "main" {
  name                = "${var.prefix}-lb"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.pip.id
  }

  tags = {
    type = "${var.lb_tag}"
  }
}


resource "azurerm_lb_backend_address_pool" "main" {
  loadbalancer_id     = azurerm_lb.main.id
  name                = "BackEndAddressPool"
}


resource "azurerm_network_interface_backend_address_pool_association" "main" {
  count                   = var.count_of_vms
  backend_address_pool_id = azurerm_lb_backend_address_pool.main.id
  ip_configuration_name   = "primary"
  network_interface_id    = element(azurerm_network_interface.main.*.id, count.index)
}


resource "azurerm_lb_nat_rule" "main" {
  resource_group_name            = azurerm_resource_group.main.name
  loadbalancer_id                = azurerm_lb.main.id
  name                           = "HTTPSAccess"
  protocol                       = "Tcp"
  frontend_port                  = 443
  backend_port                   = 443
  frontend_ip_configuration_name = azurerm_lb.main.frontend_ip_configuration[0].name
}



resource "azurerm_availability_set" "main" {
  name                          = "${var.prefix}-avset"
  location                      = azurerm_resource_group.main.location
  resource_group_name           = azurerm_resource_group.main.name
  platform_fault_domain_count   = 2
  platform_update_domain_count  = 2
  
  tags = {
    type = "${var.avset_tag}"
  }
}


data "azurerm_image" "packer-image" {
  name                  = "packer-image"
  resource_group_name   = azurerm_resource_group.main.name
}


resource "azurerm_linux_virtual_machine" "main" {
  count                           = var.count_of_vms
  name                            = "${var.prefix}-vm${count.index}"
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  size                            = "Standard_D2s_v3"
  admin_username                  = var.username
  admin_password                  = var.password
  disable_password_authentication = false
  availability_set_id             = azurerm_availability_set.main.id
  network_interface_ids = [
    azurerm_network_interface.main[count.index].id,
  ]

  source_image_id = data.azurerm_image.packer-image.id

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  tags = {
    type = "${var.vm_tag}"
  }
}


resource "azurerm_managed_disk" "main" {
  count                = var.count_of_vms
  name                 = "data-disk-${count.index}"
  location             = azurerm_resource_group.main.location
  resource_group_name  = azurerm_resource_group.main.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 128
}

resource "azurerm_virtual_machine_data_disk_attachment" "main" {
  count              = var.count_of_vms
  managed_disk_id    = azurerm_managed_disk.main.*.id[count.index]
  virtual_machine_id = azurerm_linux_virtual_machine.main.*.id[count.index]
  lun                = count.index
  caching            = "ReadWrite"
  create_option      = "Attach"
}

output "lb_url" {
  value       = "http://${azurerm_public_ip.pip.ip_address}"
  description = "The Public URL for the LB."
}

