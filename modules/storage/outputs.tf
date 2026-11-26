output "bucket_names" {
  description = "Configured bucket names; existence is reported separately. / 配置桶名；实际存在性单独输出。"
  value       = var.bucket_names
  depends_on  = [volcenginecc_tos_bucket_encryption.this]
  # EN: Inspect actual ACL for each observed bucket; deletion is shown in observed_bucket_names.
  # 中文：逐桶检查实际 ACL；桶删除在 observed_bucket_names 中显式体现。
  precondition {
    condition = alltrue([for bucket in volcenginecc_tos_bucket.this : try(
      length(bucket.acl.owner.owner_id) > 0 &&
      length(bucket.acl.grants) == 1 &&
      alltrue([for grant in bucket.acl.grants :
        grant.permission == "FULL_CONTROL" &&
        grant.grantee.type == "CanonicalUser" &&
        grant.grantee.grantee_id == bucket.acl.owner.owner_id &&
        (grant.grantee.canned == null || grant.grantee.canned == "")
      ]),
      false
    )])
    error_message = "Observed bucket ACL must grant FULL_CONTROL only to its owner. Missing ACL or additional grants require investigation."
  }
}
output "observed_bucket_names" {
  description = "Buckets present in refreshed state; missing entries indicate deletion. / 刷新后实际存在的桶；缺项表示删除。"
  value       = { for purpose, bucket in volcenginecc_tos_bucket.this : purpose => bucket.name }
}
output "private_endpoints" {
  description = "Service-reported private endpoints. / 服务返回的内网端点。"
  value       = { for purpose, bucket in volcenginecc_tos_bucket.this : purpose => bucket.intranet_endpoint }
}
