resource "local_file" "hosts_yml" {
  depends_on = [
    yandex_compute_instance.masters,
    yandex_compute_instance.workers,
    yandex_compute_instance.nat-instance,
  ]
  content = templatefile("${path.module}/hosts.tftpl",
    {
      masters = yandex_compute_instance.masters[*],
      workers  = yandex_compute_instance.workers[*],
      nat-instance = yandex_compute_instance.nat-instance,
    })
  filename = "${path.module}/../ansible/hosts.yml"
}

resource "null_resource" "install-k8s" {
  depends_on = [
    yandex_compute_instance.masters,
    yandex_compute_instance.workers,
    yandex_compute_instance.nat-instance,
  ]

  provisioner "local-exec" {
    command = "git clone https://github.com/kubernetes-sigs/kubespray.git ${path.module}/../ansible/kubespray"
  }  
  provisioner "local-exec" {
    command = "export ANSIBLE_HOST_KEY_CHECKING=False; ansible-playbook -i ${path.module}/../ansible/hosts.yml -b ${path.module}/../ansible/install-k8s.yml --extra-vars 'maximal_ansible_version=2.17.3'"
  }
}
