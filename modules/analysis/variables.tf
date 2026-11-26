variable "name" {
  description = "Cluster name. / 集群名称。"
  type        = string
}
variable "region" {
  description = "TOS region. / TOS 地域。"
  type        = string
}
variable "environment" {
  description = "Environment label. / 环境标签。"
  type        = string
}
variable "project_name" {
  description = "Existing project. / 已有项目。"
  type        = string
}
variable "zone_id" {
  description = "EMR zone. / EMR 可用区。"
  type        = string
}
variable "vpc_id" {
  description = "VPC identifier. / VPC 标识。"
  type        = string
}
variable "subnet_id" {
  description = "Dedicated EMR subnet. / EMR 专用子网。"
  type        = string
}
variable "security_group_id" {
  description = "EMR security group. / EMR 安全组。"
  type        = string
}
variable "role_name" {
  description = "ECS IAM role. / ECS IAM 角色。"
  type        = string
}
variable "release_version" {
  description = "EMR release. / EMR 版本。"
  type        = string
}
variable "instance_type" {
  description = "EMR ECS specification. / EMR ECS 规格。"
  type        = string
}
variable "disk_type" {
  description = "EMR disk type. / EMR 磁盘类型。"
  type        = string
}
variable "deploy_mode" {
  description = "EMR deployment mode. / EMR 部署模式。"
  type        = string
}
variable "core_count" {
  description = "Initial CORE count. / 初始 CORE 节点数。"
  type        = number
}
variable "key_pair_name" {
  description = "Existing EMR node key pair for key_pair login; empty for password login. / 密钥模式的 EMR 节点密钥对；密码模式留空。"
  type        = string
  default     = null
}
variable "login_mode" {
  description = "EMR node login mode: key_pair or password. / EMR 节点登录模式。"
  type        = string
  default     = "key_pair"
  nullable    = false
  validation {
    condition     = contains(["key_pair", "password"], var.login_mode)
    error_message = "login_mode must be key_pair or password."
  }
}
variable "password" {
  description = "Initial EMR node password; sensitive and stored in State/Plan. / EMR 节点初始密码，敏感值且会进入 State/Plan。"
  type        = string
  default     = null
  sensitive   = true
}
variable "metastore" {
  description = "Hive metadata connection. / Hive 元数据连接。"
  type = object({
    connection_type = string
    connection_id   = string
  })
}
variable "tos_endpoint" {
  description = "Private HTTPS TOS endpoint. / HTTPS 内网 TOS 端点。"
  type        = string
}
variable "analysis_bucket" {
  description = "Hive warehouse and results bucket. / Hive 仓库及结果桶。"
  type        = string
}
variable "tags" {
  description = "Common tags. / 公共标签。"
  type        = map(string)
}
