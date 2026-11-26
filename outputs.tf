output "network" {
  description = "Private network identifiers. / 私网资源标识。"
  value = {
    vpc_id             = module.network.vpc_id
    emr_subnet_id      = module.network.emr_subnet_id
    training_subnet_id = module.network.training_subnet_id
  }
}

output "storage" {
  description = "Retained buckets, paths and observed private endpoints. / 保留的桶、路径及服务返回的内网端点。"
  value = {
    bucket_names          = module.storage.bucket_names
    observed_bucket_names = module.storage.observed_bucket_names
    private_endpoints     = module.storage.private_endpoints
    configured_endpoint   = local.tos_endpoint
    raw_input             = "tos://${module.storage.bucket_names.raw}/input/"
    analysis_results      = "tos://${module.storage.bucket_names.analysis}/results/"
    warehouse             = "tos://${module.storage.bucket_names.analysis}/warehouse/"
    metadata_backups      = "tos://${module.storage.bucket_names.analysis}/metadata-backups/"
    training_data         = "tos://${module.storage.bucket_names.training}/datasets/"
    models                = "tos://${module.storage.bucket_names.models}/models/"
  }
}

output "emr_cluster_id" {
  description = "Optional EMR cluster identifier. / 可选 EMR 集群标识。"
  value       = var.enable_emr ? one(module.analysis[*].cluster_id) : null
}

output "training" {
  description = "Optional training node and role. / 可选训练节点及角色。"
  value = var.enable_training ? {
    instance_id = module.training[0].instance_id
    private_ip  = module.training[0].private_ip
    role_name   = module.training_identity[0].role_name
  } : null
}

output "analysis_role_name" {
  description = "Analysis ECS IAM role. / 分析节点 IAM 角色。"
  value       = var.enable_emr ? one(module.analysis_identity[*].role_name) : null
}
