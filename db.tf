locals {
  products = {
    "Consul" = {
      color      = "#dc477d"
      image_file = "hashicafe_art_consul.png"
    },
    "HCP" = {
      color      = "#ffffff"
      image_file = "hashicafe_art_hcp.png"
    },
    "Nomad" = {
      color      = "#60dea9"
      image_file = "hashicafe_art_nomad.png"
    },
    "Packer" = {
      color      = "#63d0ff"
      image_file = "hashicafe_art_packer.png"
    },
    "Terraform" = {
      color      = "#844fba"
      image_file = "hashicafe_art_terraform.png"
    },
    "Vagrant" = {
      color      = "#2e71e5"
      image_file = "hashicafe_art_vagrant.png"
    },
    "Vault" = {
      color      = "#ffec6e"
      image_file = "hashicafe_art_vault.png"
    }
  }
}

resource "aws_dynamodb_table" "products" {
  name         = "${local.name}-products"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "ProductName"

  attribute {
    name = "ProductName"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    "app.tier" = "db"
  }
}

resource "aws_dynamodb_table_item" "products" {
  table_name = aws_dynamodb_table.products.name
  hash_key   = aws_dynamodb_table.products.hash_key

  for_each = local.products

  item = <<-ITEM
    {
      "ProductName": {"S": "${each.key}"},
      "ProductColor": {"S": "${each.value.color}"},
      "LatteImage": {"S": "${each.value.image_file}"}
    }
    ITEM
}
