output "vpc_id" {
  description = "Observed VPC ID; null if the managed VPC was deleted. / 实际 VPC ID；受管 VPC 已删除时为空。"
  value       = local.vpc_id
}
output "emr_subnet_id" {
  description = "EMR subnet identifier. / EMR 子网标识。"
  value       = local.create_network ? one([for key, subnet in volcenginecc_vpc_subnet.this : subnet.subnet_id if key == "emr"]) : var.existing_network.emr_subnet_id
}
output "training_subnet_id" {
  description = "Optional training subnet. / 可选训练子网。"
  value       = var.enable_training ? (local.create_network ? one([for key, subnet in volcenginecc_vpc_subnet.this : subnet.subnet_id if key == "training"]) : var.existing_network.training_subnet_id) : null
}
output "emr_security_group_id" {
  description = "Managed foundation or read-only reused EMR security group. / 基础受管安全组或只读复用的 EMR 安全组。"
  value       = local.analysis_group.security_group_id
  precondition {
    condition     = local.analysis_group.vpc_id == local.vpc_id
    error_message = "The analysis security group must belong to the selected VPC."
  }
  precondition {
    condition = !var.enable_emr ? true : try(anytrue([
      for rule in local.analysis_group.ingress_permissions :
      rule.source_group_id == local.analysis_group.security_group_id &&
      rule.protocol == "all" && rule.policy == "accept" &&
      rule.port_start == -1 && rule.port_end == -1 && rule.direction == "ingress"
    ]), false)
    error_message = "The reused EMR security group must allow all ingress from itself. Prepare this rule before deployment; this module does not modify reused rules."
  }
  precondition {
    condition = try(
      length(local.analysis_group.egress_permissions) == 1 &&
      alltrue([for rule in local.analysis_group.egress_permissions :
        rule.cidr_ip == "0.0.0.0/0" && rule.protocol == "all" &&
        rule.port_start == -1 && rule.port_end == -1 && rule.policy == "accept" &&
        rule.priority == 100 && rule.direction == "egress"
      ]), false
    )
    error_message = "Analysis security group must have exactly the service default allow-all egress rule (priority 100). Investigate external rule changes."
  }
}
output "training_security_group_id" {
  description = "Optional training security group. / 可选训练安全组。"
  value       = var.enable_training ? one(volcenginecc_vpc_security_group.training[*].security_group_id) : null
  precondition {
    condition = alltrue([for group in volcenginecc_vpc_security_group.training :
      toset([for rule in coalesce(group.ingress_permissions, []) : jsonencode({
        cidr           = rule.cidr_ip, port_start = rule.port_start, port_end = rule.port_end,
        protocol       = rule.protocol, policy = rule.policy, priority = rule.priority,
        direction      = rule.direction, source_group_id = rule.source_group_id,
        prefix_list_id = rule.prefix_list_id
        })]) == toset([for rule in local.management_rules : jsonencode({
        cidr           = rule.cidr_ip, port_start = rule.port_start, port_end = rule.port_end,
        protocol       = rule.protocol, policy = rule.policy, priority = rule.priority,
        direction      = rule.direction, source_group_id = rule.source_group_id,
        prefix_list_id = rule.prefix_list_id
      }) if rule.port_start == 22])
    ])
    error_message = "Training ingress must exactly match authorized management SSH rules; empty management CIDRs must allow no ingress."
  }
  precondition {
    condition = alltrue([for group in volcenginecc_vpc_security_group.training : try(
      length(group.egress_permissions) == 1 &&
      alltrue([for rule in group.egress_permissions :
        rule.cidr_ip == "0.0.0.0/0" && rule.protocol == "all" &&
        rule.port_start == -1 && rule.port_end == -1 && rule.policy == "accept" &&
        rule.priority == 100 && rule.direction == "egress"
      ]), false
    )])
    error_message = "Training security group must have exactly the service default allow-all egress rule (priority 100). Investigate external rule changes."
  }
}
