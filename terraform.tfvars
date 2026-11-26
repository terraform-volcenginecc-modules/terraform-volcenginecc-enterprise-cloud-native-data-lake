# 分析部署案例：复用已有网络，启用 EMR，关闭训练。
# 部署前替换桶名、网络标识和规格，并将网段改为已有网络的实际值。
region            = "cn-beijing"
zone_id           = "cn-beijing-a"
name              = "enterprise-data-lake"
environment       = "demo"
project_name      = "default"
emr_instance_type = "ecs.r1ie.xlarge"
key_pair_name     = null
ecs_login_mode    = "password"
# 密码通过平台敏感输入或 TF_VAR_ecs_password 提供，不写入此文件。
bucket_names = {
  raw      = "replace-with-unique-lake-raw"
  analysis = "replace-with-unique-lake-analysis"
  training = "replace-with-unique-lake-training"
  models   = "replace-with-unique-lake-models"
}
management_cidrs     = []
enable_emr           = true
enable_training      = false
vpc_cidr             = "10.42.0.0/16"
emr_subnet_cidr      = "10.42.1.0/24"
training_subnet_cidr = "10.42.2.0/24"
# 替换为同地域、同可用区的已有网络；模板不会删除复用网络。
# 分析安全组须已允许所有端口的组内自引用入站，并保留唯一的默认出站规则。
existing_network = {
  vpc_id                = "vpc-xxxxxxxx"
  emr_subnet_id         = "subnet-xxxxxxxx"
  emr_security_group_id = "sg-xxxxxxxx"
}
