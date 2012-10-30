curl -i -H 'Content-Type: text/x-yaml' \
    -X POST \
    --cookie cjar \
    -T listas.yml \
    http://localhost:3000/rest/vacation
