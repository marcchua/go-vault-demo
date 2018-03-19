package vault

import (
	"encoding/json"
	"log"
	"strconv"
	"time"

	. "github.com/hashicorp/vault/api"
)

type VaultConf struct {
	Server         string
	Authentication string
	Token          string
}

var client *Client

func (c *VaultConf) InitVault() error {
	var err error
	config := DefaultConfig()
	client, err = NewClient(config)
	client.SetAddress(c.Server)
	client.SetToken(c.Token)
	return err
}

func (c *VaultConf) GetSecret(path string) (Secret, error) {
	log.Println("Starting secret retrieval")
	secret, err := client.Logical().Read(path)
	log.Println("Got Lease: " + secret.LeaseID)
	log.Println("Got Username: " + secret.Data["username"].(string))
	log.Println("Got Password: " + secret.Data["password"].(string))
	return *secret, err
}

func (c *VaultConf) RenewToken() {
	var renew bool
	var ttl string
	var maxttl string
	//See if the token we got is renewable
	log.Println("Looking up token auth")
	lookup, err := client.Auth().Token().LookupSelf()
	if err != nil {
		log.Fatal("Token is not valid. Terminating")
		return
	}
	log.Println("Token is valid")
	renew = lookup.Data["renewable"].(bool)
	log.Println("Token renewable: " + strconv.FormatBool(renew))
	//If it's not renewable exit
	if renew == false {
		log.Println("Token is not renewable. Lifecycle disabled.")
		return
	}
	//If it is let's renew it by creating the payload
	secret, err := client.Auth().Token().RenewSelf(0)
	if err != nil {
		panic(err)
	}
	//Get the creation ttl
	ttl = lookup.Data["creation_ttl"].(json.Number).String()
	maxttl = lookup.Data["explicit_max_ttl"].(json.Number).String()
	log.Println("Token creation TTL: " + string(ttl) + "s")
	log.Println("Token max TTL: " + string(maxttl) + "s")
	//Create the object. TODO look at setting increment explicitly
	renewer, err := client.NewRenewer(&RenewerInput{
		Secret: secret,
		Grace:  time.Duration(15 * time.Second),
		//Increment: 60,
	})
	//Check if we were able to create the renewer
	if err != nil {
		panic(err)
	}
	log.Println("Starting token lifecycle management for accessor " + secret.Auth.Accessor)
	//Start the renewer
	go renewer.Renew()
	defer renewer.Stop()
	//Log it
	for {
		select {
		case err := <-renewer.DoneCh():
			if err != nil {
				log.Fatal(err)
			}
			//App will terminate after token cannot be renewed. TODO: Get the remaining token duration and schedule shutdown.
			log.Fatal("Cannot renew token with accessor " + secret.Auth.Accessor + ". App will terminate.")
		case renewal := <-renewer.RenewCh():
			log.Printf("Successfully renewed accessor " + renewal.Secret.Auth.Accessor + " at: " + renewal.RenewedAt.String())
		}
	}
}

func (c *VaultConf) RenewSecret(secret Secret) error {
	renewer, err := client.NewRenewer(&RenewerInput{
		Secret: &secret,
		Grace:  time.Duration(15 * time.Second),
	})
	//Check if we were able to create the renewer
	if err != nil {
		panic(err)
	}
	log.Println("Starting secret lifecycle management for lease " + secret.LeaseID)
	//Start the renewer
	go renewer.Renew()
	defer renewer.Stop()
	//Log it
	for {
		select {
		case err := <-renewer.DoneCh():
			if err != nil {
				log.Fatal(err)
			}
			//Renewal is now past max TTL. Let app die reschedule it elsewhere. TODO: Allow for getting new creds here.
			log.Fatal("Cannot renew " + secret.LeaseID + ". App will terminate.")
		case renewal := <-renewer.RenewCh():
			log.Printf("Successfully renewed lease " + renewal.Secret.LeaseID + " at: " + renewal.RenewedAt.String())
		}
	}
}
