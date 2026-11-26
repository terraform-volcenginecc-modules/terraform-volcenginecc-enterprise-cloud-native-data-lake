variable "bucket_names" {
  description = "Purpose-to-bucket mapping. / 用途到桶名的映射。"
  type        = map(string)
}
variable "project_name" {
  description = "Existing project. / 已有项目。"
  type        = string
}
variable "tags" {
  description = "Common tags. / 公共标签。"
  type        = map(string)
}
variable "analysis_scratch_retention_days" {
  description = "Scratch expiration; zero disables. / 临时目录过期天数，0 关闭。"
  type        = number
}
