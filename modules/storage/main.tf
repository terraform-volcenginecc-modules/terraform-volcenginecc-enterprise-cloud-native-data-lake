# EN: Four private versioned buckets separate data uses and survive compute release.
# 中文：四个私有版本化桶隔离数据用途，并在计算资源释放后保留。
resource "volcenginecc_tos_bucket" "this" {
  for_each              = var.bucket_names
  name                  = each.value
  project_name          = var.project_name
  bucket_type           = "fns"
  storage_class         = "STANDARD"
  enable_version_status = "Enabled"
  acl_grant = {
    acl                = "private"
    grant_full_control = ""
    grant_read         = ""
    grant_read_acp     = ""
    grant_write        = ""
    grant_write_acp    = ""
  }
  tags = [for key, value in var.tags : { key = key, value = value }]

  # EN: Only explicitly disposable scratch data expires. Historical versions remain.
  # 中文：仅显式定义的临时目录过期，历史版本继续保留。
  # EN: Keep a disabled rule at zero so resetting a previously enabled rule really stops expiry.
  # 中文：0 使用禁用规则，使曾开启的过期策略真正关闭；null 不会清除 Optional+Computed 字段。
  lifecycle_config = each.key == "analysis" ? [{
    lifecycle_rule_id                  = "analysis-scratch-only"
    prefix                             = "scratch/"
    status                             = var.analysis_scratch_retention_days > 0 ? "Enabled" : "Disabled"
    expiration                         = { days = max(var.analysis_scratch_retention_days, 1), date = null }
    abort_in_complete_multipart_upload = null
    filter                             = null
    no_current_version_expiration      = null
    non_current_version_transitions    = null
    transitions                        = null
    tags                               = null
  }] : null

  lifecycle {
    prevent_destroy = true
    # EN: CCAPI returns ACL, but not the write-only ACLGrant request.
    # 中文：CCAPI 回读 ACL，不回读 ACLGrant 请求字段；实际授权仍检查。
    ignore_changes = [acl_grant]
  }
}

resource "volcenginecc_tos_bucket_encryption" "this" {
  for_each      = var.bucket_names
  name          = volcenginecc_tos_bucket.this[each.key].name
  sse_algorithm = "AES256"
}
