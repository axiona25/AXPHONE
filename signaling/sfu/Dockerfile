FROM golang:1.22-alpine
WORKDIR /app
COPY . .
RUN echo "// TODO: integrare ion-sfu/pion con SFrame E2EE" > main.go &&     printf 'package main\nimport (\"fmt\")\nfunc main(){fmt.Println(\"SFU placeholder\")}' > main.go &&     go build -o sfu main.go
EXPOSE 7000
CMD ["/app/sfu"]
