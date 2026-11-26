# EN: Dedicated private subnets isolate EMR and optional training; no public IP/NAT.
# 中文：专用私网子网隔离 EMR 和可选训练节点，不配置公网 IP 或 NAT。
locals {
  create_network             = var.existing_network == null
  existing_analysis_group_id = var.existing_network == null ? null : var.existing_network.emr_security_group_id
  create_analysis_group      = local.existing_analysis_group_id == null
  analysis_group             = local.create_analysis_group ? one(volcenginecc_vpc_security_group.analysis[*]) : one(data.volcenginecc_vpc_security_group.analysis[*])
  # EN: A missing managed VPC is observable as null during refresh-only.
  # 中文：refresh-only 时已删除的受管 VPC 显式显示为空，正常部署仍必须提供 ID。
  vpc_id = local.create_network ? one(volcenginecc_vpc_vpc.this[*].vpc_id) : var.existing_network.vpc_id
  subnets = merge(
    { emr = var.emr_subnet_cidr },
    var.enable_training ? { training = var.training_subnet_cidr } : {}
  )
  management_rules = flatten([
    for cidr in sort(tolist(var.management_cidrs)) : [
      for port in [22, 443] : {
        cidr_ip  = cidr, description = "Authorized management", direction = "ingress",
        policy   = "accept", port_start = port, port_end = port, priority = 10,
        protocol = "tcp", prefix_list_id = "", source_group_id = ""
      }
    ]
  ])
}

resource "volcenginecc_vpc_vpc" "this" {
  count        = local.create_network ? 1 : 0
  vpc_name     = var.name
  cidr_block   = var.vpc_cidr
  project_name = var.project_name
  tags         = [for key, value in var.tags : { key = key, value = value }]
}

resource "volcenginecc_vpc_subnet" "this" {
  depends_on  = [time_sleep.vpc_child_release_wait]
  for_each    = local.create_network ? local.subnets : {}
  vpc_id      = local.vpc_id
  zone_id     = var.zone_id
  subnet_name = "${var.name}-${each.key}"
  cidr_block  = each.value
  tags        = [for key, value in var.tags : { key = key, value = value }]
}

// EN: VPC -> delay -> children on create; all children -> delay -> VPC on destroy.
// 中文：仅为本模板管理的 VPC 创建等待对象，不接管外部复用网络。
resource "time_sleep" "vpc_child_release_wait" {
  count      = local.create_network ? 1 : 0
  depends_on = [volcenginecc_vpc_vpc.this]

  destroy_duration = "${var.vpc_child_release_wait_seconds}s"
  triggers = {
    vpc_id = local.vpc_id
  }
}

# EN: All cluster ports are limited to the dedicated EMR subnet, not the entire VPC.
# 中文：集群内部端口仅对 EMR 专用子网开放，不对整个 VPC 开放。
resource "volcenginecc_vpc_security_group" "analysis" {
  count = local.create_analysis_group ? 1 : 0
  # EN: Avoid concurrent subnet/security-group operations on a newly created VPC.
  # 中文：避免新 VPC 的子网与安全组操作并发冲突。
  depends_on          = [volcenginecc_vpc_subnet.this, time_sleep.vpc_child_release_wait]
  vpc_id              = local.vpc_id
  security_group_name = "${var.name}-analysis"
  project_name        = var.project_name
  description         = "EMR dedicated subnet and authorized management"
  ingress_permissions = concat([{
    cidr_ip  = var.emr_subnet_cidr, description = "EMR internal traffic", direction = "ingress",
    policy   = "accept", port_start = -1, port_end = -1, priority = 1,
    protocol = "all", prefix_list_id = "", source_group_id = ""
  }], local.management_rules)
  # EN: VPC creates an allow-all egress rule (priority 100). Re-adding it conflicts.
  # 中文：VPC 自动创建优先级 100 的全部放行出站规则；重复添加会冲突。
  # EN: Its exact readback is checked by the security-group output precondition.
  # 中文：安全组输出前置条件核对该默认规则的精确回读。
  tags = [for key, value in var.tags : { key = key, value = value }]
  lifecycle {
    precondition {
      condition     = !var.enable_emr
      error_message = "EMR requires existing_network.emr_security_group_id with self-reference ingress. volcenginecc 0.0.74 has no separate rule resource for a new group's self-reference; prepare an EMR-ready group before enabling compute. Network-only creation remains supported."
    }
  }
}

// EN: Preserve existing managed-state addresses when the optional reuse branch is added.
// 中文：增加可选复用分支时，保留原受管安全组的 State 地址映射。
moved {
  from = volcenginecc_vpc_security_group.analysis
  to   = volcenginecc_vpc_security_group.analysis[0]
}

# EN: Read-only reuse keeps EMR-owned ingress outside Terraform's full rule-set writer.
# 中文：只读复用，不使用 Terraform 的完整规则写入覆盖 EMR 托管规则。
data "volcenginecc_vpc_security_group" "analysis" {
  count = local.create_analysis_group ? 0 : 1
  id    = local.existing_analysis_group_id
}

resource "volcenginecc_vpc_security_group" "training" {
  depends_on          = [volcenginecc_vpc_security_group.analysis, time_sleep.vpc_child_release_wait]
  count               = var.enable_training ? 1 : 0
  vpc_id              = local.vpc_id
  security_group_name = "${var.name}-training"
  project_name        = var.project_name
  description         = "Training SSH and platform outbound"
  # EN: An intentionally empty ingress policy is returned as null by CCAPI.
  # 中文：明确不开放管理入站时，CCAPI 将空规则回读为 null。
  ingress_permissions = length(local.management_rules) == 0 ? null : [for rule in local.management_rules : rule if rule.port_start == 22]
  # EN: Use and validate the service-created default egress rule.
  # 中文：使用并校验服务自动创建的默认出站规则。
  tags = [for key, value in var.tags : { key = key, value = value }]
  lifecycle {
    precondition {
      condition     = var.existing_network == null ? true : try(length(var.existing_network.training_subnet_id) > 0, false)
      error_message = "Reused networks must supply training_subnet_id when training is enabled."
    }
  }
}
