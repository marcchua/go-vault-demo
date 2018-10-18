package service

import (
	"encoding/base64"
	"log"
	"strconv"
	"time"

  "github.com/lanceplarsen/go-vault-demo/client"
  "github.com/lanceplarsen/go-vault-demo/dao"
  "github.com/lanceplarsen/go-vault-demo/models"
)

type Order struct {
	Vault    *client.Vault
  Dao      *dao.Order
}


func (o *Order) GetOrders() ([]models.Order, error) {
	var eOrders []models.Order
	var dOrders []models.Order

	eOrders, err := o.Dao.FindAll()
	if err != nil {
		return []models.Order{}, err
	}

	//Decrypt these. TODO Could use a batch decyrpt opp here
	for _, order := range eOrders {
		dOrder, err := o.Vault.Decrypt("/transit/decrypt/order", order.CustomerName)
		if err != nil {
			log.Printf("Unable to decrypt order: %s", strconv.FormatInt(order.Id, 10))
		} else {
			sDec, _ := base64.StdEncoding.DecodeString(dOrder)
			order.CustomerName = string(sDec)
			dOrders = append(dOrders, order)
		}
	}

	return dOrders, nil
}

func (o *Order) CreateOrder(order models.Order) (models.Order, error) {
	//Get the unencrypted customer to send back to the API
	ucust := order.CustomerName

	//Add a timestamp
	order.OrderDate = time.Now()

	//Encrypt it
	encode := base64.StdEncoding.EncodeToString([]byte(order.CustomerName))
	//Get plaintext customer
	cipher, err := o.Vault.Encrypt("/transit/encrypt/order", encode)
	if err != nil {
		return order, err
	}

	//Insert the order
	order.CustomerName = cipher
	o.Dao.Insert(order)

	//If the order was inserted successfully send back the unencrypted customer
	order.CustomerName = ucust

	return models.Order{}, nil
}


func (o *Order) DeleteOrders() error {
  err := o.Dao.DeleteAll()
	return err
}
