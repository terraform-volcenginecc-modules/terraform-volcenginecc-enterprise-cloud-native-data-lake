variable "name" {
  description = "Resource prefix. / 资源前缀。"
  type        = string
}
variable "project_name" {
  description = "Existing project. / 已有项目。"
  type        = string
}
variable "zone_id" {
  description = "Subnet zone. / 子网可用区。"
  type        = string
}
variable "vpc_cidr" {
  description = "VPC CIDR. / VPC 网段。"
  type        = string
}
variable "emr_subnet_cidr" {
  description = "Dedicated EMR CIDR. / EMR 专用网段。"
  type        = string
}
variable "training_subnet_cidr" {
  description = "Training CIDR. / 训练网段。"
  type        = string
}
variable "existing_network" {
  description = "Optional existing network. / 可选的已有网络。"
  type = object({
    vpc_id                = string
    emr_subnet_id         = string
    training_subnet_id    = optional(string)
    emr_security_group_id = optional(string)
  })
  default = null
}
variable "management_cidrs" {
  description = "Authorized management CIDRs. / 授权管理网段。"
  type        = set(string)
}
variable "enable_training" {
  description = "Enable training network. / 启用训练网络。"
  type        = bool
}
variable "enable_emr" {
  description = "Require a pre-existing EMR-ready security group for analysis compute. / 分析计算要求复用已具备组内互通规则的安全组。"
  type        = bool
  default     = false
}
variable "tags" {
  description = "Common tags. / 公共标签。"
  type        = map(string)
}

variable "vpc_child_release_wait_seconds" {
  description = "Destroy-only delay after managed VPC child deletion and before VPC deletion. / 受管 VPC 子资源删除后、VPC 删除前的销毁等待。"
  type        = number
  default     = 120
  nullable    = false
  validation {
    condition     = var.vpc_child_release_wait_seconds >= 0 && var.vpc_child_release_wait_seconds <= 900 && floor(var.vpc_child_release_wait_seconds) == var.vpc_child_release_wait_seconds
    error_message = "Use an integer between 0 and 900 seconds; 0 disables the delay."
  }
}
