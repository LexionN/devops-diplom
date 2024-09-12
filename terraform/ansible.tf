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
  filename = "${abspath(path.module)}/../ansible/hosts.yml"
}

resource "null_resource" "install-k8s" {
  depends_on = [
    yandex_compute_instance.masters,
    yandex_compute_instance.workers,
    yandex_compute_instance.nat-instance,
  ]
  
  provisioner "local-exec" {
    command = "export ANSIBLE_HOST_KEY_CHECKING=False; ansible-playbook -i ../ansible/hosts.yml -b ../ansible/install-k8s.yml"
  }  
   
}
