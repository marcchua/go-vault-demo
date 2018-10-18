package dao

import (
	"fmt"

	"github.com/go-pg/pg"
	"github.com/lanceplarsen/go-vault-demo/models"
)

type Order struct {
	Host     string
	Port     string
	Database string
	User     string
	Password string
}

var db *pg.DB

func (o *Order) Connect() error {
	var n int

	//conn string
	db = pg.Connect(&pg.Options{
		User:     o.User,
		Password: o.Password,
		Addr:     fmt.Sprintf("%s:%s", o.Host, o.Port),
		Database: o.Database,
	})

	//Check our connection
	_, err := db.QueryOne(pg.Scan(&n), "SELECT 1")
	return err
}

func (o *Order) Close() error {
	err := db.Close()
	return err
}

func (o *Order) FindAll() ([]models.Order, error) {
	var orders []models.Order

	//Go get the orders
	err := db.Model(&orders).Select()
	if err != nil {
		return []models.Order{}, err
	}

	return orders, nil
}

func (o *Order) DeleteAll() error {
	var ids []int

	//Find the order ids
	err := db.Model(&Order{}).Column("id").Select(&ids)
	if err != nil {
		return err
	}

	//Delete the order ids if we have results
	if len(ids) > 0 {
		pgids := pg.In(ids)
		_, err := db.Model(&Order{}).Where("id IN (?)", pgids).Delete()
		if err != nil {
			return err
		}
	}

	return nil
}

func (o *Order) Insert(order models.Order) (models.Order, error) {
	err := db.Insert(&order)
	if err != nil {
		return order, err
	}

	return order, nil
}
