# EN: EMR analysis using the bundled Proton connector and role-based TOS access.
# 中文：EMR 通过内置 Proton 连接器和角色临时凭证访问 TOS。
locals {
  login_key_pair = var.key_pair_name == null ? null : (trimspace(var.key_pair_name) == "" ? null : var.key_pair_name)
  login_password = var.password == null ? null : (trimspace(var.password) == "" ? null : var.password)
  scope = {
    effective_type   = "CLUSTER"
    component_names  = []
    node_group_ids   = []
    node_group_names = []
    node_group_types = []
    node_ids         = []
    node_names       = []
  }
  configs = {
    HDFS = {
      "fs.tos.endpoint"             = var.tos_endpoint
      "fs.tos.region"               = var.region
      "fs.tos.credentials.provider" = "io.proton.common.object.tos.auth.IAMInstanceCredentialsProvider"
      # Versioned TOS buckets cannot use RenameObject; Proton must copy then delete.
      # 版本控制桶不支持 RenameObject，使用 Proton 复制后删除的兼容路径。
      "fs.tos.rename.enabled" = "false"
    }
    HIVE = {
      "hive.metastore.warehouse.dir"          = "tos://${var.analysis_bucket}/warehouse/managed"
      "hive.metastore.warehouse.external.dir" = "tos://${var.analysis_bucket}/warehouse/external"
    }
  }
}

# EN: Do not hide application/node configuration changes with ignore_changes.
# 中文：不使用 ignore_changes 隐藏应用或节点配置变更。
resource "volcenginecc_emr_cluster" "this" {
  project_name        = var.project_name
  cluster_name        = var.name
  cluster_type        = "Hadoop"
  release_version     = var.release_version
  application_names   = ["HDFS", "YARN", "HIVE", "SPARK3"]
  deploy_mode         = var.deploy_mode
  security_mode       = "SIMPLE"
  charge_type         = "POST"
  vpc_id              = var.vpc_id
  security_group_id   = var.security_group_id
  history_server_mode = "LOCAL"
  node_attribute = {
    zone_id      = var.zone_id
    ecs_iam_role = var.role_name
  }
  node_group_attributes = [
    for group in [
      { name = "MasterGroup", type = "MASTER", count = var.deploy_mode == "HIGH_AVAILABLE" ? 3 : 1, disks = 1 },
      { name = "CoreGroup", type = "CORE", count = var.core_count, disks = 4 }
      ] : {
      zone_id            = var.zone_id
      subnet_ids         = [var.subnet_id]
      node_group_name    = group.name
      node_group_type    = group.type
      node_count         = group.count
      ecs_instance_types = [var.instance_type]
      ecs_key_pair_name  = var.login_mode == "key_pair" ? local.login_key_pair : ""
      ecs_password       = var.login_mode == "password" ? local.login_password : ""
      with_public_ip     = false
      bandwidth          = 8
      charge_type        = "POST"
      system_disk        = { volume_type = var.disk_type, size = 120 }
      data_disks         = [{ volume_type = var.disk_type, size = 80, count = group.disks }]
    }
  ]
  application_extras = [
    for app in ["HDFS", "HIVE"] : {
      application_name              = app
      connection_type               = app == "HIVE" ? var.metastore.connection_type : null
      connection_id                 = app == "HIVE" ? var.metastore.connection_id : null
      application_component_layouts = []
      application_configs = [
        for key in sort(keys(local.configs[app])) : {
          config_file_name        = app == "HDFS" ? "core-site.xml" : "hive-site.xml"
          config_item_key         = key
          config_item_value       = local.configs[app][key]
          deleted                 = false
          component_instance_name = ""
          component_name          = ""
          effective_scope         = local.scope
        }
      ]
    }
  ]
  bootstrap_scripts = []
  tags              = [for key, value in var.tags : { key = key, value = value }]

  lifecycle {
    precondition {
      condition = (
        (var.login_mode == "key_pair" && local.login_key_pair != null && local.login_password == null) ||
        (var.login_mode == "password" && local.login_key_pair == null && local.login_password != null)
      )
      error_message = "key_pair login requires only key_pair_name; password login requires only password. Leave the other credential null or empty."
    }
    precondition {
      condition     = var.vpc_id != null && var.subnet_id != null && var.security_group_id != null
      error_message = "EMR requires an existing VPC, subnet and security group; reconcile missing network resources before deployment."
    }
    precondition {
      condition     = var.environment != "prod" || (var.metastore.connection_type != "BUILT_IN_MYSQL" && var.deploy_mode == "HIGH_AVAILABLE")
      error_message = "prod requires an existing external metadata connection and HIGH_AVAILABLE. These are necessary but not sufficient production readiness checks."
    }
  }
}
