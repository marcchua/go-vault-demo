package config

import (
	"log"

	"github.com/BurntSushi/toml"
)

type Config struct {
	DB    Database `toml:"database"`
	Vault Vault
}

type Database struct {
	Server string
	Role   string
	Name   string
}

type Vault struct {
	Server         string
	Authentication string
	Token          string
}

func (c *Config) Read() {
	if _, err := toml.DecodeFile("config.toml", &c); err != nil {
		log.Fatal(err)
	}
}
