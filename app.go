package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gorilla/mux"
	. "github.com/lanceplarsen/vaultdemo/config"
	. "github.com/lanceplarsen/vaultdemo/dao"
	. "github.com/lanceplarsen/vaultdemo/models"
	. "github.com/lanceplarsen/vaultdemo/vault"
)

var config = Config{}
var dao = OrdersDAO{}
var vault = VaultConf{}

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
	var order Order
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
	config.Read()

	//Vault Init
	vault.Server = config.Vault.Server
	vault.Authentication = config.Vault.Authentication

	//Auth to Vault
	//TODO Add K8s
	//TODO Add renewel support for tokens
	log.Println("Authenticating to Vault")
	log.Println("Using token authentication")
	if len(config.Vault.Token) > 0 {
		  log.Println("Vault token found in config file")
	    vault.Token = config.Vault.Token
	} else if len(os.Getenv("VAULT_TOKEN")) > 0 {
			log.Println("Vault token found in VAULT_TOKEN")
			vault.Token = os.Getenv("VAULT_TOKEN")
	} else {
		log.Fatal("Could get Vault token. Terminating.")
	}

	//Init the Vault
	err := vault.InitVault()
	if err != nil {
		log.Fatal(err)
	}

	//Now that we have a Vault token we can see if we can renew it.
	//If it's renewable we will start renew loop in this Goroutine
	go vault.RenewToken()

	//Get our DB secrets
	secret, err := vault.GetSecret(config.DB.Role)
	if err != nil {
		log.Fatal(err)
	}

	//Start our Goroutine Renewal for the DB creds
	go vault.RenewSecret(secret)

	//DAO config
	dao.Url = config.DB.Server
	dao.Database = config.DB.Name
	dao.User = secret.Data["username"].(string)
	dao.Password = secret.Data["password"].(string)

	//Check our conn
	log.Println("Starting DB initialization")
	err = dao.Connect()
	if err != nil {
		log.Fatal(err)
	}
	log.Println("DB initialization complete")

	//Looks good
	log.Println("Server initialization complete")
}

func main() {
	//Router
	r := mux.NewRouter()
	r.HandleFunc("/api/orders", AllOrdersEndpoint).Methods("GET")
	r.HandleFunc("/api/orders", CreateOrderEndpoint).Methods("POST")
	r.HandleFunc("/api/orders", DeleteOrdersEndpoint).Methods("DELETE")
	log.Println("Server is now running on port 3000")
	//Catch SIGINT so we can revoke all our secrets gracefully. TODO
	var gracefulStop = make(chan os.Signal)
	//signal.Notify(gracefulStop, syscall.SIGTERM)
	signal.Notify(gracefulStop, syscall.SIGINT)
	go func() {
		sig := <-gracefulStop
		fmt.Printf("caught sig: %+v", sig)
		log.Println("Wait for 2 second to finish processing")
		time.Sleep(2 * time.Second)
		os.Exit(0)
	}()
	//Start server
	if err := http.ListenAndServe(":3000", r); err != nil {
		log.Fatal(err)
	}
}
