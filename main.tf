# EN: Compose storage, identity, network and optional compute without provisioners.
# 中文：编排存储、身份、网络及可选计算，不通过 provisioner 执行脚本。
locals {
  common_tags = {
    Name        = var.name
    Environment = var.environment
    Project     = var.project_name
    Owner       = var.owner
    CostCenter  = var.cost_center
  }
  tos_endpoint = coalesce(var.tos_endpoint, "https://tos-${var.region}.ivolces.com")
}

module "storage" {
  source                          = "./modules/storage"
  bucket_names                    = var.bucket_names
  project_name                    = var.project_name
  tags                            = local.common_tags
  analysis_scratch_retention_days = var.analysis_scratch_retention_days
}

module "network" {
  source                         = "./modules/network"
  name                           = var.name
  project_name                   = var.project_name
  zone_id                        = var.zone_id
  vpc_cidr                       = var.vpc_cidr
  emr_subnet_cidr                = var.emr_subnet_cidr
  training_subnet_cidr           = var.training_subnet_cidr
  existing_network               = var.existing_network
  management_cidrs               = var.management_cidrs
  enable_training                = var.enable_training
  enable_emr                     = var.enable_emr
  vpc_child_release_wait_seconds = var.vpc_child_release_wait_seconds
  tags                           = local.common_tags
}

module "analysis_identity" {
  count            = var.enable_emr ? 1 : 0
  source           = "./modules/identity"
  name             = "${var.name}-analysis"
  enable_emr_trust = true
  read_buckets     = [module.storage.bucket_names.raw]
  write_buckets    = [module.storage.bucket_names.analysis]
  denied_buckets   = [module.storage.bucket_names.training, module.storage.bucket_names.models]
  tags             = local.common_tags
}

module "training_identity" {
  count          = var.enable_training ? 1 : 0
  source         = "./modules/identity"
  name           = "${var.name}-training"
  read_buckets   = [module.storage.bucket_names.training]
  write_buckets  = [module.storage.bucket_names.models]
  denied_buckets = [module.storage.bucket_names.raw, module.storage.bucket_names.analysis]
  tags           = local.common_tags
}

module "analysis" {
  count             = var.enable_emr ? 1 : 0
  source            = "./modules/analysis"
  name              = var.name
  region            = var.region
  environment       = var.environment
  project_name      = var.project_name
  zone_id           = var.zone_id
  vpc_id            = module.network.vpc_id
  subnet_id         = module.network.emr_subnet_id
  security_group_id = module.network.emr_security_group_id
  role_name         = module.analysis_identity[0].role_name
  release_version   = var.emr_release_version
  instance_type     = var.emr_instance_type
  disk_type         = var.emr_disk_type
  deploy_mode       = var.emr_deploy_mode
  core_count        = var.emr_core_count
  key_pair_name     = var.key_pair_name
  login_mode        = var.ecs_login_mode
  password          = var.ecs_login_mode == "password" ? var.ecs_password : null
  metastore         = var.metastore
  tos_endpoint      = local.tos_endpoint
  analysis_bucket   = module.storage.bucket_names.analysis
  tags              = local.common_tags
}

module "training" {
  count                    = var.enable_training ? 1 : 0
  source                   = "./modules/training"
  name                     = var.name
  project_name             = var.project_name
  zone_id                  = var.zone_id
  vpc_id                   = module.network.vpc_id
  subnet_id                = module.network.training_subnet_id
  security_group_id        = module.network.training_security_group_id
  role_name                = module.training_identity[0].role_name
  image_id                 = var.training_image_id
  instance_type            = var.training_instance_type
  key_pair_name            = var.key_pair_name
  login_mode               = var.ecs_login_mode
  password                 = var.ecs_login_mode == "password" ? var.ecs_password : null
  eni_release_wait_seconds = var.eni_release_wait_seconds
  tags                     = local.common_tags
}
