resource "yandex_container_registry" "my_registry" {
  name      = "my-registry"
}

# resource "yandex_container_registry_iam_binding" "puller" {
#   registry_id = yandex_container_registry.my_registry.id
#   role        = "container-registry.images.puller"

#   members = [
#     "serviceAccount:var.account_id",
#   ]
# }