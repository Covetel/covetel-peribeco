curl -i -D header-login.txt --location \
    --data "login=$1" \
    --data 'passw=123321...' \
    --data 'Botones.submit=Ingresar' \
    --cookie-jar cjar http://127.0.0.1:3000/login
