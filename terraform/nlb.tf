# Создаю группу балансировщика
resource "yandex_lb_target_group" "nlb-group" {
  name       = "nlb-group"
  depends_on = [yandex_compute_instance.workers]
  dynamic "target" {
    for_each = yandex_compute_instance.workers
    content { 
      subnet_id = target.value.network_interface.0.subnet_id
      address   = target.value.network_interface.0.ip_address
    }
  }
}

# Создаю балансировщик grafana
resource "yandex_lb_network_load_balancer" "nlb-grafana" {
  name = "nlb-grafana"
  listener {
    name        = "grafana-listener"
    port        = 3000
    target_port = 31000
    external_address_spec {
      ip_version = "ipv4"
    }
  }
  attached_target_group {
    target_group_id = yandex_lb_target_group.nlb-group.id
    healthcheck {
      name = "healthcheck-grafana"
      tcp_options {
        port = 31000
      }
    }
  }
  depends_on = [yandex_lb_target_group.nlb-group]
}

