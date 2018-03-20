FROM golang:alpine
WORKDIR /app
ADD go-vault-demo /app/
ENTRYPOINT ["/app/go-vault-demo"]
EXPOSE 3000
