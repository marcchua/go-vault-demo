package config

import (
	"log"

	"github.com/spf13/viper"
)

type Config struct {
	Database Database
	Vault    Vault
}

type Database struct {
	Server string
	Name   string
	Role   string
}

type Vault struct {
	Host           string
	Port           string
	Scheme         string
	Authentication string
	Credential     string
	Role           string
}

func (c *Config) Read() {
	viper.SetConfigName("config")
	viper.AddConfigPath(".")
	//Vault Defaults
	viper.SetDefault("Vault.Host", "127.0.0.1")
	viper.SetDefault("Vault.Port", "8200")
	viper.SetDefault("Vault.Scheme", "http")
	viper.SetDefault("Vault.Authentication", "token")
	//DB Defaults
	viper.SetDefault("Database.Server", "localhost:5432")
	viper.SetDefault("Database.Name", "postgres")
	//Read it
	if err := viper.ReadInConfig(); err != nil {
		log.Fatalf("Error reading config file, %s", err)
	}
	err := viper.Unmarshal(&c)
	if err != nil {
		log.Fatalf("unable to decode into struct, %v", err)
	}
}
