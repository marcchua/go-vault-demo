package dao

import (
	"log"
	"time"

	"github.com/go-pg/pg"
	"github.com/go-pg/pg/orm"
	. "github.com/lanceplarsen/vaultdemo/models"
)

type OrdersDAO struct {
	Url      string
	Database string
	User     string
	Password string
}

var db *pg.DB

func (o *OrdersDAO) Connect() error {
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

func (o *OrdersDAO) Close() error {
	err := db.Close()
	return err

}

func (o *OrdersDAO) FindAll() ([]Order, error) {
	var orders []Order
	err := db.Model(&orders).Select()
	return orders, err
}

func (o *OrdersDAO) DeleteAll() error {
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

func (o *OrdersDAO) Insert(order Order) (Order, error) {
	//Add a timestamp
	order.OrderDate = time.Now()
	//Insert the order
	err := db.Insert(&order)
	return order, err
}
