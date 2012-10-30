curl -i -D get_vacation_header.txt -H 'Content-Type: application/json' \
    -X GET \
    --cookie cjar \
    http://localhost:3000/rest/vacation/
