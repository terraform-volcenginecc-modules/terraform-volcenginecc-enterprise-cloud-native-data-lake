variable "name" {
  description = "Resource prefix. / 资源前缀。"
  type        = string
}
variable "project_name" {
  description = "Existing project. / 已有项目。"
  type        = string
}
variable "zone_id" {
  description = "ECS zone. / ECS 可用区。"
  type        = string
}
variable "vpc_id" {
  description = "VPC identifier. / VPC 标识。"
  type        = string
}
variable "subnet_id" {
  description = "Training subnet. / 训练子网。"
  type        = string
}
variable "security_group_id" {
  description = "Training security group. / 训练安全组。"
  type        = string
}
variable "role_name" {
  description = "Training IAM role. / 训练 IAM 角色。"
  type        = string
}
variable "image_id" {
  description = "Prepared training image. / 预制训练镜像。"
  type        = string
}
variable "instance_type" {
  description = "CPU ECS specification. / CPU ECS 规格。"
  type        = string
}
variable "key_pair_name" {
  description = "Existing ECS key pair for key_pair login; empty for password login. / 密钥模式使用的已有 ECS 密钥对；密码模式留空。"
  type        = string
  default     = null
}
variable "login_mode" {
  description = "ECS login mode: key_pair or password. / ECS 登录模式。"
  type        = string
  default     = "key_pair"
  nullable    = false
  validation {
    condition     = contains(["key_pair", "password"], var.login_mode)
    error_message = "login_mode must be key_pair or password."
  }
}
variable "password" {
  description = "Initial ECS password; sensitive and stored in State/Plan. / ECS 初始密码，敏感值且会进入 State/Plan。"
  type        = string
  default     = null
  sensitive   = true
}
variable "tags" {
  description = "Common tags. / 公共标签。"
  type        = map(string)
}

variable "eni_release_wait_seconds" {
  description = "Destroy-only delay after ECS deletion and before security group deletion. / ECS 删除后、安全组删除前的销毁等待。"
  type        = number
  default     = 120
  nullable    = false
  validation {
    condition     = var.eni_release_wait_seconds >= 0 && var.eni_release_wait_seconds <= 900 && floor(var.eni_release_wait_seconds) == var.eni_release_wait_seconds
    error_message = "Use an integer between 0 and 900 seconds; 0 disables the delay."
  }
}
