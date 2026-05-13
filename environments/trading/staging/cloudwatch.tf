locals {
  # Add one entry per asset to onboard: "SYMBOL" = "asset_type"
  # e.g. "ETH-USDT" = "crypto"
  assets = {
    "BTC-USDT" = "crypto"
  }

  layers = ["L1-data", "L2-indicators", "L2-qualitative", "L3-regime", "L3-conviction", "L4-execution", "L5-pnl"]

  # Unique asset types for the group-level error log groups
  asset_types = distinct(values(local.assets))

  # Flattened brain log group definitions
  brain_groups = {
    for item in flatten([
      for asset, asset_type in local.assets : [
        for layer in local.layers : {
          key        = "${asset_type}/${asset}/brain/${layer}"
          path       = "/behemoth/${var.env}/${asset_type}/${asset}/brain/${layer}"
          asset      = asset
          asset_type = asset_type
          layer      = layer
        }
      ]
    ]) : item.key => item
  }

  # Flattened layer-level error log group definitions
  layer_error_groups = {
    for item in flatten([
      for asset, asset_type in local.assets : [
        for layer in local.layers : {
          key        = "${asset_type}/${asset}/errors/${layer}"
          path       = "/behemoth/${var.env}/${asset_type}/${asset}/errors/${layer}"
          asset      = asset
          asset_type = asset_type
          layer      = layer
        }
      ]
    ]) : item.key => item
  }
}

# Global brain error log group — infra-level errors, startup failures, cross-cutting
resource "aws_cloudwatch_log_group" "global_errors" {
  name              = "/behemoth/${var.env}/errors"
  retention_in_days = 30
  tags = {
    Name        = "behemoth-${var.env}-global-errors"
    Environment = var.env
    ManagedBy   = "terraform"
    Project     = var.project
  }
}

# Asset-type error groups — one per asset class (e.g. /behemoth/staging/crypto/errors)
resource "aws_cloudwatch_log_group" "asset_type_errors" {
  for_each          = toset(local.asset_types)
  name              = "/behemoth/${var.env}/${each.key}/errors"
  retention_in_days = 30
  tags = {
    Name        = "behemoth-${var.env}-${each.key}-errors"
    AssetType   = each.key
    Environment = var.env
    ManagedBy   = "terraform"
    Project     = var.project
  }
}

# Brain log groups — operational INFO+ logs per asset per layer
resource "aws_cloudwatch_log_group" "brain" {
  for_each          = local.brain_groups
  name              = each.value.path
  retention_in_days = 30
  tags = {
    Name        = "behemoth-${var.env}-${each.value.asset}-${each.value.layer}-brain"
    Symbol      = each.value.asset
    AssetType   = each.value.asset_type
    Layer       = each.value.layer
    Environment = var.env
    ManagedBy   = "terraform"
    Project     = var.project
  }
}

# Layer error groups — ERROR+ logs isolated per asset per layer
resource "aws_cloudwatch_log_group" "layer_errors" {
  for_each          = local.layer_error_groups
  name              = each.value.path
  retention_in_days = 30
  tags = {
    Name        = "behemoth-${var.env}-${each.value.asset}-${each.value.layer}-errors"
    Symbol      = each.value.asset
    AssetType   = each.value.asset_type
    Layer       = each.value.layer
    Environment = var.env
    ManagedBy   = "terraform"
    Project     = var.project
  }
}
