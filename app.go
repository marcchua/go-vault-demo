package main

import (
	"crypto/tls"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"

	"github.com/dimiro1/health"
	"github.com/dimiro1/health/db"
	"github.com/gorilla/mux"
	"github.com/lanceplarsen/go-vault-demo/client"
	"github.com/lanceplarsen/go-vault-demo/config"
	"github.com/lanceplarsen/go-vault-demo/dao"
	"github.com/lanceplarsen/go-vault-demo/models"
	"github.com/lanceplarsen/go-vault-demo/service"
	_ "github.com/lib/pq"
)

var orderService = service.Order{}

func AllOrdersEndpoint(w http.ResponseWriter, r *http.Request) {
	orders, err := orderService.GetOrders()
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
	var order models.Order

	defer r.Body.Close()
	if err := json.NewDecoder(r.Body).Decode(&order); err != nil {
		respondWithError(w, http.StatusBadRequest, "Invalid request payload")
		return
	}
	//Respond with the updated order
	order, err := orderService.CreateOrder(order)
	if err != nil {
		respondWithError(w, http.StatusInternalServerError, err.Error())
		return
	}
	respondWithJson(w, http.StatusCreated, order)
}

func DeleteOrdersEndpoint(w http.ResponseWriter, r *http.Request) {
	if err := orderService.DeleteOrders(); err != nil {
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

func main() {
	log.Println("Starting server initialization")

	//Get our config from the file
	var configurator = config.Config{}
	configurator.Read()

	//Server params
	var credential = client.Credential{
		Token:          configurator.Vault.Credential.Token,
		RoleID:         configurator.Vault.Credential.RoleID,
		SecretID:       configurator.Vault.Credential.SecretID,
		ServiceAccount: configurator.Vault.Credential.ServiceAccount,
	}

	var vault = client.Vault{
		Host:           configurator.Vault.Host,
		Port:           configurator.Vault.Port,
		Scheme:         configurator.Vault.Scheme,
		Authentication: configurator.Vault.Authentication,
		Role:           configurator.Vault.Role,
		Mount:          configurator.Vault.Mount,
		Credential:     credential,
	}

	//Init it
	log.Println("Starting vault initialization")
	err := vault.Initialize()
	if err != nil {
		log.Fatal(err)
	}

	//Make sure we got a DB role
	log.Println("Starting DB initialization")
	if len(configurator.Vault.Database.Role) == 0 {
		log.Fatal("Could not get DB role from config.")
	}

	//See if we need to go get dyanmic DB creds
	if len(configurator.Database.Username) == 0 && len(configurator.Database.Password) == 0 {
		log.Printf("DB role: %s", configurator.Vault.Database.Role)
		secret, err := vault.GetSecret(fmt.Sprintf("%s/creds/%s", configurator.Vault.Database.Mount, configurator.Vault.Database.Role))
		if err != nil {
			log.Fatal(err)
		}
		//Update our configuration with the dynamic creds
		configurator.Database.Username = secret.Data["username"].(string)
		configurator.Database.Password = secret.Data["password"].(string)
		//Start our Goroutine Renewal for the DB creds
		go vault.RenewSecret(secret)
	}

	//DAO config
	var orderDao = dao.Order{
		Host:     configurator.Database.Host,
		Port:     configurator.Database.Port,
		Database: configurator.Database.Name,
		User:     configurator.Database.Username,
		Password: configurator.Database.Password,
	}

	//Check our DAO connection
	err = orderDao.Connect()
	if err != nil {
		log.Fatal(err)
	}

	//Get our TLS cert from Vault
	cert, err := vault.GetCertificate(fmt.Sprintf("%s/issue/%s", configurator.Vault.Pki.Mount, configurator.Vault.Pki.Role), configurator.Vault.Pki.CN)
	if err != nil {
		log.Fatal(err)
	}

	public := cert.Data["certificate"].(string)
	private := cert.Data["private_key"].(string)
	publicBytes := []byte(public)
	privateBytes := []byte(private)

	x509, err := tls.X509KeyPair(publicBytes, privateBytes)
	if err != nil {
		log.Fatal(err)
	}

	//Create service
	orderService.Vault = &vault
	orderService.Dao = &orderDao
	orderService.Encyrption.Key = configurator.Vault.Transit.Key
	orderService.Encyrption.Mount = configurator.Vault.Transit.Mount

	//Router
	r := mux.NewRouter()

	//API Routes
	r.HandleFunc("/api/orders", AllOrdersEndpoint).Methods("GET")
	r.HandleFunc("/api/orders", CreateOrderEndpoint).Methods("POST")
	r.HandleFunc("/api/orders", DeleteOrdersEndpoint).Methods("DELETE")

	//Health Check Routes
	h := health.NewHandler()
	conn := fmt.Sprintf("user=%s password=%s dbname=%s host=%s sslmode=disable", configurator.Database.Username, configurator.Database.Password, configurator.Database.Name, configurator.Database.Host)
	database, _ := sql.Open("postgres", conn)
	pg := db.NewPostgreSQLChecker(database)
	h.AddChecker("Postgres", pg)
	r.Path("/health").Handler(h).Methods("GET")

	//Server config - http
	go func() {
		log.Println(fmt.Sprintf("Server is now accepting http requests on port %v", configurator.Server.Port))
		if err := http.ListenAndServe(fmt.Sprintf(":%v", configurator.Server.Port), r); err != nil {
			log.Fatal(err)
		}
	}()

	//Server config - https
	go func() {
		tlsConfig := &tls.Config{Certificates: []tls.Certificate{x509}}
		s := &http.Server{
			Addr:      ":8443",
			Handler:   r,
			TLSConfig: tlsConfig,
		}
		log.Println(fmt.Sprintf("Server is now accepting https requests on port 8443"))
		if err := s.ListenAndServeTLS("", ""); err != nil {
			log.Fatal(err)
		}
	}()

	//Catch SIGINT AND SIGTERM to gracefully tear down tokens and secrets
	var gracefulStop = make(chan os.Signal)
	signal.Notify(gracefulStop, syscall.SIGTERM)
	signal.Notify(gracefulStop, syscall.SIGINT)
	sig := <-gracefulStop
	fmt.Printf("caught sig: %+v", sig)
	vault.Close()
	os.Exit(0)

}
