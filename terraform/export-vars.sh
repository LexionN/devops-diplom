#!/bin/bash

# Сохранить output в JSON файл
terraform output -json > tf_outputs.json

# Преобразовать JSON в YAML
jq -r 'to_entries | map(.key + ": " + .value.value) | .[]' tf_outputs.json > ../k8s/tf_outputs.yml