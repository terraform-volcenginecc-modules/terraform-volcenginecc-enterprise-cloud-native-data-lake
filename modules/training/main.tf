# EN: Optional CPU training host from a prepared image; business jobs run manually.
# 中文：使用预制镜像的可选 CPU 训练主机，业务作业由用户显式提交。
locals {
  login_key_pair = var.key_pair_name == null ? null : (trimspace(var.key_pair_name) == "" ? null : var.key_pair_name)
  login_password = var.password == null ? null : (trimspace(var.password) == "" ? null : var.password)
}

// EN: SG -> delay -> ECS on create; ECS -> delay -> SG on destroy.
// 中文：通过安全组 ID 保留跨模块依赖，仅销毁阶段等待网卡异步释放。
resource "time_sleep" "eni_release_wait" {
  destroy_duration = "${var.eni_release_wait_seconds}s"
  triggers = {
    security_group_id = var.security_group_id
  }
}

resource "volcenginecc_ecs_instance" "this" {
  depends_on = [time_sleep.eni_release_wait]

  instance_name        = "${var.name}-training"
  project_name         = var.project_name
  zone_id              = var.zone_id
  instance_type        = var.instance_type
  instance_charge_type = "PostPaid"
  image = {
    image_id              = var.image_id
    keep_image_credential = false
  }
  key_pair   = var.login_mode == "key_pair" ? { key_pair_name = local.login_key_pair } : null
  password   = var.login_mode == "password" ? local.login_password : null
  role_names = [var.role_name]
  primary_network_interface = {
    vpc_id             = var.vpc_id
    subnet_id          = var.subnet_id
    security_group_ids = [var.security_group_id]
  }
  system_volume = {
    volume_type          = "ESSD_PL0"
    size                 = 80
    delete_with_instance = true
  }
  tags = [for key, value in var.tags : { key = key, value = value }]
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
      error_message = "Training requires an existing VPC, subnet and security group; reconcile missing network resources before deployment."
    }
    precondition {
      condition     = try(length(trimspace(var.image_id)) > 0, false) && try(length(trimspace(var.instance_type)) > 0, false)
      error_message = "Training requires an available prepared image ID and ECS instance type."
    }
  }
}
