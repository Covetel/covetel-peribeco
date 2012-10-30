curl -i -D get_forward_header.txt -H 'Content-Type: application/json' \
    -X GET \
    --cookie cjar \
    http://localhost:3000/rest/forwards/
