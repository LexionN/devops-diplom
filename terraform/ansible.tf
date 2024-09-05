# resource "null_resource" "clone-kubespray" {
  
#   provisioner "local-exec" {
#     command = "rm -rf ../ansible/kubespray; git clone https://github.com/kubernetes-sigs/kubespray.git ../ansible/kubespray"
#   }
  
# }

resource "local_file" "hosts_yml" {
  depends_on = [
    yandex_compute_instance.masters,
    yandex_compute_instance.workers,
  ]
  content = templatefile("${path.module}/hosts.tftpl",
    {
      masters = yandex_compute_instance.masters[*],
      workers  = yandex_compute_instance.workers[*],
    })
  filename = "${abspath(path.module)}/../ansible/hosts.yml"
}

resource "null_resource" "install-k8s" {
  depends_on = [
    yandex_compute_instance.masters,
    yandex_compute_instance.workers,
  ]

  # #Добавление ключа в ssh-agent
  # provisioner "local-exec" {
  #   command = "echo '${local.metadata_vm.ssh-keys}' | ssh-add"
  # }

  # Запуск подготовки к установке на мастер ноде
  provisioner "local-exec" {
    command = "export ANSIBLE_HOST_KEY_CHECKING=False; ansible-playbook -i ../ansible/hosts.yml ../ansible/prep.yml"
  }

  
}

