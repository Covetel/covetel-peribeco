curl -i -H 'Content-Type: text/x-yaml' \
    -X DELETE \
    --cookie cjar \
    -T listas.yml \
    http://localhost:3000/ajax/delete/lista
