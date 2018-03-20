package dao

import (
	"encoding/base64"
	"log"
	"time"

	"github.com/go-pg/pg"
	"github.com/go-pg/pg/orm"
	. "github.com/lanceplarsen/go-vault-demo/client"
	. "github.com/lanceplarsen/go-vault-demo/models"
)

type OrderDAO struct {
	Url      string
	Database string
	User     string
	Password string
	Vault    *Vault
}

var db *pg.DB

func (o *OrderDAO) Connect() error {
	db = pg.Connect(&pg.Options{
		User:     o.User,
		Password: o.Password,
		Addr:     o.Url,
		Database: o.Database,
	})
	//Check our connection
	var n int
	_, err := db.QueryOne(pg.Scan(&n), "SELECT 1")
	return err
}

func (o *OrderDAO) Close() error {
	err := db.Close()
	return err

}

func (o *OrderDAO) FindAll() ([]Order, error) {
	var eOrders []Order
	var dOrders []Order
	err := db.Model(&eOrders).Select()
	//Decrypt these. TODO Could use a batch decyrpt opp here
	for _, order := range eOrders {
		eOrder := o.Vault.Decrypt(order.CustomerName)
		sDec, _ := base64.StdEncoding.DecodeString(eOrder)
		order.CustomerName = string(sDec)
		dOrders = append(dOrders, order)
	}
	return dOrders, err
}

func (o *OrderDAO) DeleteAll() error {
	var ids []int
	var res orm.Result
	//Find the order ids
	err := db.Model(&Order{}).Column("id").Select(&ids)
	//Delete the order ids if we have results
	if len(ids) > 0 {
		pgids := pg.In(ids)
		res, err = db.Model(&Order{}).Where("id IN (?)", pgids).Delete()
		log.Println("Deleted records", res.RowsAffected())
	} else {
		log.Println("No records to delete.")
	}
	return err
}

func (o *OrderDAO) Insert(order Order) (Order, error) {
	//Add a timestamp
	order.OrderDate = time.Now()
	//Encrypt it
	encode := base64.StdEncoding.EncodeToString([]byte(order.CustomerName))
	//Get plaintext customer
	order.CustomerName = o.Vault.Encrypt(encode)
	//Insert the order
	err := db.Insert(&order)
	return order, err
}
