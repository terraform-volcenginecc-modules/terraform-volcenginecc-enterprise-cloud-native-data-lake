# EN: One ECS-trusted role with bucket-scoped permissions per workload.
# 中文：每条业务链路独立使用一个 ECS 可信角色，并限制到指定桶。
locals {
  readable_objects = ["tos:GetObject", "tos:HeadObject", "tos:GetObjectTagging", "tos:GetFileStatus"]
  writable_objects = concat(local.readable_objects, [
    "tos:PutObject", "tos:DeleteObject", "tos:DeleteObjects",
    "tos:CreateMultipartUpload", "tos:UploadPart", "tos:CompleteMultipartUpload",
    "tos:AbortMultipartUpload", "tos:ListMultipartUploadParts", "tos:CopyObject", "tos:RenameObject",
    "tos:UploadPartCopy", "tos:SetObjectMeta", "tos:PutObjectTagging"
  ])
  object_trns = { for b in concat(var.read_buckets, var.write_buckets) : b => "trn:tos:::${b}/*" }
}

resource "volcenginecc_iam_policy" "this" {
  policy_name = var.name
  policy_type = "Custom"
  description = "Dedicated data lake workload policy"
  policy_document = jsonencode({
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["tos:HeadBucket", "tos:ListBucket"]
        Resource = [for b in concat(var.read_buckets, var.write_buckets) : "trn:tos:::${b}"]
      },
      {
        # EN: Proton's output committer lists pending uploads at bucket scope.
        # 中文：Proton 输出提交器在桶级列举未完成分片，仅授权输出桶。
        Effect   = "Allow"
        Action   = ["tos:ListBucketMultipartUploads"]
        Resource = [for b in var.write_buckets : "trn:tos:::${b}"]
      },
      {
        Effect   = "Allow"
        Action   = local.readable_objects
        Resource = [for b in var.read_buckets : local.object_trns[b]]
      },
      {
        Effect   = "Allow"
        Action   = local.writable_objects
        Resource = [for b in var.write_buckets : local.object_trns[b]]
      },
      {
        Effect   = "Deny"
        Action   = ["tos:*"]
        Resource = flatten([for b in var.denied_buckets : ["trn:tos:::${b}", "trn:tos:::${b}/*"]])
      },
      {
        Effect   = "Deny"
        Action   = ["tos:Put*", "tos:Delete*", "tos:CreateMultipartUpload", "tos:Upload*", "tos:CompleteMultipartUpload", "tos:AbortMultipartUpload", "tos:AppendObject", "tos:RenameObject", "tos:CopyObject", "tos:SetObjectMeta"]
        Resource = [for b in var.read_buckets : local.object_trns[b]]
      }
    ]
  })
}

resource "volcenginecc_iam_role" "this" {
  role_name            = var.name
  description          = "Dedicated data lake ECS workload role"
  max_session_duration = 3600
  trust_policy_document = jsonencode({
    Statement = [{
      Effect    = "Allow"
      Action    = ["sts:AssumeRole"]
      Principal = { Service = var.enable_emr_trust ? ["Volc_ECS", "emr"] : ["Volc_ECS"] }
    }]
  })
  policies = [{
    policy_name = volcenginecc_iam_policy.this.policy_name
    policy_type = "Custom"
  }]
  tags = [for key, value in var.tags : { key = key, value = value }]
}
