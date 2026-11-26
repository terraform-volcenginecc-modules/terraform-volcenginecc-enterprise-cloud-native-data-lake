variable "region" {
  description = "Deployment region shared by compute and TOS. / 计算和 TOS 使用的同一地域。"
  type        = string
  default     = "cn-beijing"
}

variable "zone_id" {
  description = "An available EMR/ECS zone in the selected region. / 当前地域内支持 EMR/ECS 的可用区。"
  type        = string
}

variable "name" {
  description = "Resource name prefix, 3-32 lowercase characters. / 资源名称前缀，3-32 位小写字符。"
  type        = string
  default     = "enterprise-data-lake"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}[a-z0-9]$", var.name))
    error_message = "Use 3-32 lowercase letters, digits or hyphens, beginning with a letter."
  }
}

variable "environment" {
  description = "Environment label: demo, test or prod. / 环境标签。"
  type        = string
  default     = "demo"
  validation {
    condition     = contains(["demo", "test", "prod"], var.environment)
    error_message = "environment must be demo, test or prod."
  }
}

variable "project_name" {
  description = "Existing Volcengine project. / 已有火山引擎项目。"
  type        = string
  default     = "default"
}

variable "owner" {
  description = "Non-sensitive owner/team label. / 非敏感的责任团队标签。"
  type        = string
  default     = "data-platform"
}

variable "cost_center" {
  description = "Cost allocation label. / 成本归属标签。"
  type        = string
  default     = "data-platform"
}

variable "bucket_names" {
  description = "Four distinct, globally unique bucket names. / 四个不同且全局唯一的桶名。"
  type = object({
    raw      = string
    analysis = string
    training = string
    models   = string
  })
  validation {
    condition = length(distinct(values(var.bucket_names))) == 4 && alltrue([
      for name in values(var.bucket_names) :
      length(name) >= 3 && length(name) <= 63 && can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", name))
    ])
    error_message = "Use four distinct TOS bucket names, each 3-63 lowercase letters, digits or hyphens."
  }
}

variable "tos_endpoint" {
  description = "Same-region HTTPS private TOS service endpoint; null derives the standard endpoint. / 同地域 HTTPS 内网 TOS 服务端点，null 使用标准地址。"
  type        = string
  default     = null
  validation {
    condition     = var.tos_endpoint == null ? true : can(regex("^https://[a-z0-9.-]+$", var.tos_endpoint))
    error_message = "Provide an HTTPS service endpoint without a path or credentials."
  }
}

variable "vpc_cidr" {
  description = "VPC IPv4 CIDR; also describes a reused VPC. / VPC IPv4 网段，复用时也需准确填写。"
  type        = string
  default     = "10.42.0.0/16"
  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be a valid IPv4 CIDR."
  }
}

variable "emr_subnet_cidr" {
  description = "Dedicated trusted EMR subnet, used for intra-cluster access. / EMR 专用可信子网，用于集群内部互通。"
  type        = string
  default     = "10.42.1.0/24"
  validation {
    condition     = can(cidrnetmask(var.emr_subnet_cidr)) && var.emr_subnet_cidr != "0.0.0.0/0"
    error_message = "Provide a valid dedicated IPv4 subnet."
  }
}

variable "training_subnet_cidr" {
  description = "Separate training subnet. / 独立的训练子网。"
  type        = string
  default     = "10.42.2.0/24"
  validation {
    condition     = can(cidrnetmask(var.training_subnet_cidr)) && var.training_subnet_cidr != "0.0.0.0/0"
    error_message = "Provide a valid training IPv4 subnet."
  }
}

variable "existing_network" {
  description = "Reuse dedicated VPC/subnets and optionally an EMR-ready security group; EMR requires that group with this Provider. / 复用专用 VPC/子网及可选的 EMR 就绪安全组；当前 Provider 启用 EMR 必须提供该安全组。"
  type = object({
    vpc_id                = string
    emr_subnet_id         = string
    training_subnet_id    = optional(string)
    emr_security_group_id = optional(string)
  })
  default = null
  validation {
    condition = var.existing_network == null ? true : (
      var.existing_network.emr_security_group_id == null ? true :
      can(regex("^sg-[a-z0-9]+$", var.existing_network.emr_security_group_id))
    )
    error_message = "existing_network.emr_security_group_id must be a nonempty security-group ID when provided."
  }
}

variable "management_cidrs" {
  description = "Authorized management networks for SSH and EMR HTTPS; empty denies extra inbound access. / SSH 与 EMR HTTPS 的授权管理网段，空列表不开放额外入站。"
  type        = set(string)
  default     = []
  validation {
    condition = alltrue([
      for cidr in var.management_cidrs : can(cidrnetmask(cidr)) && !can(regex("/0$", cidr))
    ])
    error_message = "Use explicit authorized IPv4 CIDRs; /0 is forbidden."
  }
}

variable "enable_emr" {
  description = "Create analysis compute; false releases EMR while retaining TOS. / 创建分析计算；关闭时释放 EMR，保留 TOS。"
  type        = bool
  default     = true
}

variable "emr_release_version" {
  description = "Region-supported release with HDFS, YARN, HIVE and SPARK3. / 地域支持且包含所需组件的 EMR 版本。"
  type        = string
  default     = "3.19.0"
}

variable "emr_instance_type" {
  description = "EMR-supported ECS specification with available capacity. / EMR 支持且有库存的 ECS 规格。"
  type        = string
}

variable "emr_disk_type" {
  description = "EMR disk type; validate release/zone compatibility. / EMR 磁盘类型，需确认版本及可用区兼容性。"
  type        = string
  default     = "ESSD_FlexPL"
}

variable "emr_deploy_mode" {
  description = "SIMPLE has one Master; HIGH_AVAILABLE requests three Masters in the same zone. / SIMPLE 单 Master；HIGH_AVAILABLE 请求同可用区三 Master。"
  type        = string
  default     = "SIMPLE"
  validation {
    condition     = contains(["SIMPLE", "HIGH_AVAILABLE"], var.emr_deploy_mode)
    error_message = "Use SIMPLE or HIGH_AVAILABLE."
  }
}

variable "emr_core_count" {
  description = "Initial CORE node count; editing may replace the cluster. / 初始 CORE 节点数，修改可能重建集群。"
  type        = number
  default     = 2
  validation {
    condition     = var.emr_core_count >= 2 && var.emr_core_count <= 1000 && floor(var.emr_core_count) == var.emr_core_count
    error_message = "Use an integer from 2 to 1000."
  }
}

variable "key_pair_name" {
  description = "Existing EMR/training ECS key pair for key_pair login; leave null or empty for password login. / 密钥模式使用的已有 EMR/训练 ECS 密钥对；密码模式留空。"
  type        = string
  default     = null
}

variable "ecs_login_mode" {
  description = "EMR and training ECS login: key_pair or password. / EMR 与训练 ECS 登录模式：key_pair 或 password。"
  type        = string
  default     = "key_pair"
  nullable    = false
  validation {
    condition     = contains(["key_pair", "password"], var.ecs_login_mode)
    error_message = "ecs_login_mode must be key_pair or password."
  }
}

variable "ecs_password" {
  description = "Initial EMR/training ECS password for password login; supply through a sensitive input or TF_VAR_ecs_password. Stored in State and saved Plan. / 密码模式的 EMR/训练 ECS 初始密码，通过敏感输入或 TF_VAR_ecs_password 提供；会进入 State 和保存的 Plan。"
  type        = string
  default     = null
  sensitive   = true
  validation {
    condition = var.ecs_password == null ? true : (trimspace(var.ecs_password) == "" ? true : (
      length(var.ecs_password) >= 8 && length(var.ecs_password) <= 30 &&
      sum([
        for pattern in ["[A-Z]", "[a-z]", "[0-9]", "[^A-Za-z0-9]"] :
        length(regexall(pattern, var.ecs_password)) > 0 ? 1 : 0
      ]) >= 3 &&
      can(regex("^[A-Za-z0-9`~!@#$%^&*()_+={}\\[\\]:;'<>,.?/|\\-]+$", var.ecs_password)) &&
      !startswith(var.ecs_password, "/") && !startswith(var.ecs_password, "$6$")
    ))
    error_message = "Use an 8-30 character ECS password with at least three character classes and supported characters; it cannot start with / or $6$."
  }
}

variable "metastore" {
  description = "Built-in demo metadata or an existing EMR metadata connection. / 演示内置元数据库或已有 EMR 元数据连接。"
  type = object({
    connection_type = optional(string, "BUILT_IN_MYSQL")
    connection_id   = optional(string, "")
  })
  default = {}
  validation {
    condition = contains(["BUILT_IN_MYSQL", "EXTERNAL_MYSQL", "HIVE_METASTORE"], var.metastore.connection_type) && (
      var.metastore.connection_type == "BUILT_IN_MYSQL"
      ? var.metastore.connection_id == ""
      : length(trimspace(var.metastore.connection_id)) > 0
    )
    error_message = "External MySQL/HMS requires an existing connection ID; built-in mode requires an empty ID."
  }
}

variable "enable_training" {
  description = "Create one CPU ECS training node and its isolated IAM role. / 创建一个 CPU ECS 训练节点及独立 IAM 身份。"
  type        = bool
  default     = false
}

variable "training_image_id" {
  description = "Prepared Linux image with Python 3 and TOS SDK; required when training is enabled. / 预装 Python 3 与 TOS SDK 的 Linux 镜像。"
  type        = string
  default     = null
}

variable "training_instance_type" {
  description = "CPU ECS specification; required when training is enabled. / CPU ECS 规格，启用训练时必填。"
  type        = string
  default     = null
}

variable "analysis_scratch_retention_days" {
  description = "Days before deleting analysis scratch/ objects; 0 disables. Never applies to results or datasets. / 分析桶 scratch/ 临时数据保留天数，0 关闭。"
  type        = number
  default     = 0
  validation {
    condition     = var.analysis_scratch_retention_days >= 0 && floor(var.analysis_scratch_retention_days) == var.analysis_scratch_retention_days
    error_message = "Use a nonnegative integer."
  }
}

variable "eni_release_wait_seconds" {
  description = "Destroy-only delay between training ECS and security group deletion; apply before teardown. / 训练 ECS 删除后、安全组删除前的销毁等待，须提前 Apply。"
  type        = number
  default     = 120
  nullable    = false
  validation {
    condition     = var.eni_release_wait_seconds >= 0 && var.eni_release_wait_seconds <= 900 && floor(var.eni_release_wait_seconds) == var.eni_release_wait_seconds
    error_message = "Use an integer between 0 and 900 seconds; 0 disables the delay."
  }
}

variable "vpc_child_release_wait_seconds" {
  description = "Destroy-only delay between managed VPC child deletion and VPC deletion; excludes reused networks. / 受管子网和安全组删除后、VPC 删除前的销毁等待，不适用于外部复用网络。"
  type        = number
  default     = 120
  nullable    = false
  validation {
    condition     = var.vpc_child_release_wait_seconds >= 0 && var.vpc_child_release_wait_seconds <= 900 && floor(var.vpc_child_release_wait_seconds) == var.vpc_child_release_wait_seconds
    error_message = "Use an integer between 0 and 900 seconds; 0 disables the delay."
  }
}
