# resource "local_file" "hosts_yml" {
#   depends_on = [
#     yandex_compute_instance.masters,
#     yandex_compute_instance.workers,
#   ]
#   content = templatefile("${path.module}/hosts.tftpl",
#     {
#       masters = yandex_compute_instance.masters[*],
#       workers  = yandex_compute_instance.workers[*],
#     })
#   filename = "${abspath(path.module)}/../ansible/hosts.yml"
# }

# resource "null_resource" "prepare-k8s" {
#   depends_on = [
#     yandex_compute_instance.masters,
#     yandex_compute_instance.workers,
#   ]
  
#   # Запуск подготовки к установке на мастер ноде
#   provisioner "local-exec" {
#     command = "export ANSIBLE_HOST_KEY_CHECKING=False; ansible-playbook -i ../ansible/hosts.yml ../ansible/prep.yml"
#   }

#   }
resource "null_resource" "install-k8s" {
  depends_on = [
    yandex_compute_instance.masters,
    yandex_compute_instance.workers,
    # null_resource.prepare-k8s,
  ]
  
  
  provisioner "local-exec" {
    command = "ssh ubuntu@${yandex_compute_instance.masters.network_interface[0].nat_ip_address} 'sudo -i && cd ~/kubespray && ansible-playbook -i ./inventory/hosts.yml -b cluster.yml'"
  }  
   
}


