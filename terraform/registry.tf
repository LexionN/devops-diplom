resource "yandex_container_registry" "my_registry" {
  name      = "my-registry"
}

resource "null_resource" "docker" {
  triggers = {
    always_run = "${timestamp()}"
  }
  depends_on = [yandex_container_registry.my_registry]
  
  #Создаем image контейнера
  provisioner "local-exec" {
    command = "docker build . -t cr.yandex/${yandex_container_registry.my_registry.id}/nginx:1.0.0 -f Dockerfile"
    working_dir = "${path.module}/../docker"
  }  

  #Размещаем image в созданном registry
  provisioner "local-exec" {
    command = "docker push cr.yandex/${yandex_container_registry.my_registry.id}/nginx:1.0.0"
    working_dir = "${path.module}/../docker"
  }  
}