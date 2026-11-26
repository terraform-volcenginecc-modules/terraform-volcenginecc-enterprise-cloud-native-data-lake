output "instance_id" {
  description = "Training ECS identifier. / 训练 ECS 标识。"
  value       = volcenginecc_ecs_instance.this.instance_id
}
output "private_ip" {
  description = "Private address. / 私网地址。"
  value       = volcenginecc_ecs_instance.this.primary_network_interface.primary_ip_address
}
