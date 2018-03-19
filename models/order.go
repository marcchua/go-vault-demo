package models

import "time"

type Order struct {
	Id           int64     `json:"id"`
	CustomerName string    `json:"CustomerName"`
	ProductName  string    `json:"ProductName"`
	OrderDate    time.Time `json:"OrderDate"`
}
