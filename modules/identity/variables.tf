variable "name" {
  description = "Role and policy name. / 角色与策略名称。"
  type        = string
}
variable "read_buckets" {
  description = "Read-only input buckets. / 只读输入桶。"
  type        = list(string)
}
variable "write_buckets" {
  description = "Read/write output buckets. / 可读写输出桶。"
  type        = list(string)
}
variable "denied_buckets" {
  description = "Buckets explicitly denied to this role. / 显式禁止访问的桶。"
  type        = list(string)
}
variable "tags" {
  description = "Common tags. / 公共标签。"
  type        = map(string)
}
variable "enable_emr_trust" {
  description = "Allow EMR to assume the analysis node role alongside ECS. / 分析角色除 ECS 外，还允许 EMR 服务代入。"
  type        = bool
  default     = false
}
