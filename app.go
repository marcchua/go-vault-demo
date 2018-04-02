package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"

	"github.com/gorilla/mux"
	"github.com/lanceplarsen/go-vault-demo/client"
	"github.com/lanceplarsen/go-vault-demo/config"
	. "github.com/lanceplarsen/go-vault-demo/dao"
	"github.com/lanceplarsen/go-vault-demo/models"
)

var configurator = config.Config{}
var vault = client.Vault{}
var dao = OrderDAO{}

func AllOrdersEndpoint(w http.ResponseWriter, r *http.Request) {
	orders, err := dao.FindAll()
	if err != nil {
		respondWithError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if len(orders) > 0 {
		respondWithJson(w, http.StatusOK, orders)
	} else {
		respondWithJson(w, http.StatusOK, map[string]string{"result": "No orders"})
	}
}

func CreateOrderEndpoint(w http.ResponseWriter, r *http.Request) {
	defer r.Body.Close()
	var order models.Order
	if err := json.NewDecoder(r.Body).Decode(&order); err != nil {
		respondWithError(w, http.StatusBadRequest, "Invalid request payload")
		return
	}
	//Respond with the updated order
	order, err := dao.Insert(order)
	if err != nil {
		respondWithError(w, http.StatusInternalServerError, err.Error())
		return
	}
	respondWithJson(w, http.StatusCreated, order)
}

func DeleteOrdersEndpoint(w http.ResponseWriter, r *http.Request) {
	if err := dao.DeleteAll(); err != nil {
		respondWithError(w, http.StatusInternalServerError, err.Error())
		return
	}
	respondWithJson(w, http.StatusOK, map[string]string{"result": "success"})
}

func respondWithError(w http.ResponseWriter, code int, msg string) {
	respondWithJson(w, code, map[string]string{"error": msg})
}

func respondWithJson(w http.ResponseWriter, code int, payload interface{}) {
	response, _ := json.Marshal(payload)
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	w.Write(response)
}

func init() {
	log.Println("Starting server initialization")
	//Get our config from the file
	configurator.Read()
	log.Println("Starting vault initialization")
	//Server params
	vault.Server = configurator.Vault.Server
	vault.Authentication = configurator.Vault.Authentication
	//Auth param
	vault.Credential = configurator.Vault.Credential
	//Optional role param for auth
	vault.Role = configurator.Vault.Role
	//Init it
	err := vault.Init()
	if err != nil {
		log.Fatal(err)
	}
	log.Println("Vault initialization complete")

	log.Println("Starting DB initialization")
	//Make sure we got a DB role
	if len(configurator.Database.Role) > 0 {
		log.Println("DB role is " + configurator.Database.Role)
	} else {
		log.Fatal("Could not get DB role from config.")
	}

	log.Println("Starting secret retrieval")
	//Get our DB secrets
	secret, err := vault.GetSecret(configurator.Database.Role)
	if err != nil {
		log.Fatal(err)
	}
	//Start our Goroutine Renewal for the DB creds
	go vault.RenewSecret(secret)

	//DAO config
	dao.Vault = &vault
	dao.Url = configurator.Database.Server
	dao.Database = configurator.Database.Name
	dao.User = secret.Data["username"].(string)
	dao.Password = secret.Data["password"].(string)

	//Check our DB Conn
	err = dao.Connect()
	if err != nil {
		log.Fatal(err)
	}
	log.Println("DB initialization complete")

	log.Println("Server initialization complete")
}

func main() {
	//Router
	r := mux.NewRouter()
	r.HandleFunc("/api/orders", AllOrdersEndpoint).Methods("GET")
	r.HandleFunc("/api/orders", CreateOrderEndpoint).Methods("POST")
	r.HandleFunc("/api/orders", DeleteOrdersEndpoint).Methods("DELETE")
	log.Println("Server is now accepting requests on port 3000")
	//Catch SIGINT AND SIGTERM to tear down tokens and secrets
	var gracefulStop = make(chan os.Signal)
	signal.Notify(gracefulStop, syscall.SIGTERM)
	signal.Notify(gracefulStop, syscall.SIGINT)
	go func() {
		sig := <-gracefulStop
		fmt.Printf("caught sig: %+v", sig)
		vault.Close()
		os.Exit(0)
	}()
	//Start server
	if err := http.ListenAndServe(":3000", r); err != nil {
		log.Fatal(err)
	}
}
