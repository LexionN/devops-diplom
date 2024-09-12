output "Grafana_address" {
  value = [
    for listener in yandex_lb_network_load_balancer.nlb-grafana.listener :
    [
      for spec in listener.external_address_spec :
      "http://${spec.address}:${listener.port}"
    ][0]
  ][0]
}
