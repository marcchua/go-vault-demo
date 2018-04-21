package client

import (
	"errors"
	"io/ioutil"
	"log"

	. "github.com/hashicorp/vault/api"
)

type Vault struct {
	Server         string
	Authentication string
	Credential     string
	Role           string
}

var client *Client

func (v *Vault) Init() error {
	var err error
	var renew bool
	var ttl string
	var maxttl string
	var token string

	//Default client
	config := DefaultConfig()
	client, err = NewClient(config)
	//Set the address
	err = client.SetAddress(v.Server)
	if err != nil {
		return err
	}

	//Auth to Vault
	log.Println("Client authenticating to Vault")
	switch v.Authentication {
	case "token":
		log.Println("Using token authentication")
		if len(client.Token()) > 0 {
			log.Println("Got token from VAULT_TOKEN")
			break
		} else if len(v.Credential) > 0 {
			token = v.Credential
			log.Println("Got token from config file")
		} else {
			log.Fatal("Could not get Vault token. Terminating.")
		}
		client.SetToken(token)
	case "kubernetes":
		log.Println("Using kubernetes authentication")
		//Check Role
		if len(v.Role) > 0 {
			log.Println("Role is " + v.Role)
		} else {
			return errors.New("K8s role not in config.")
		}
		//Check JWT
		if len(v.Credential) > 0 {
			log.Println("Service account JWT file is " + v.Credential)
		} else {
			return errors.New("K8s JWT file not in config.")
		}
		//Get the JWT from POD
		jwt, err := ioutil.ReadFile(v.Credential)
		if err != nil {
			return err
		}
		//Payload
		data := map[string]interface{}{"jwt": string(jwt), "role": v.Role}
		//Auth with K8s vault
		secret, err := client.Logical().Write("auth/kubernetes/login", data)
		if err != nil {
			return err
		}
		//Log our metadata
		log.Println("Dumping K8s metadata...")
		log.Println(secret.Auth.Metadata)
		//Get the client token
		token = secret.Auth.ClientToken
		client.SetToken(token)
	default:
		log.Fatal("Auth method " + v.Authentication + " is not supported")
	}

	//See if the token we got is renewable
	log.Println("Looking up token")
	lookup, err := client.Auth().Token().LookupSelf()
	//If token is not valid so get out of here early
	if err != nil {
		return err
	}
	
	//Check renewable
	renew = lookup.Data["renewable"].(bool)
	//If it's not renewable log it. If it is start the renewal.
	if renew == false {
		log.Println("Token is not renewable. Token lifecycle disabled.")
	} else {
		go v.RenewToken()
	}

	return nil
}

func (c *Vault) GetSecret(path string) (Secret, error) {
	log.Println("Getting secret: " + path)
	secret, err := client.Logical().Read(path)
	if err != nil {
		return Secret{}, err
	}
	log.Println("Got Lease: " + secret.LeaseID)
	log.Println("Got Username: " + secret.Data["username"].(string))
	//log.Println("Got Password: " + secret.Data["password"].(string))
	return *secret, nil
}

func (v *Vault) RenewToken() {
	//If it is let's renew it by creating the payload
	secret, err := client.Auth().Token().RenewSelf(0)
	if err != nil {
		log.Fatal(err)
	}

	//Create the object. TODO look at setting increment explicitly
	renewer, err := client.NewRenewer(&RenewerInput{
		Secret: secret,
		//Grace:  time.Duration(15 * time.Second),
		//Increment: 60,
	})

	//Check if we were able to create the renewer
	if err != nil {
		log.Fatal(err)
	}

	//Start the renewer
	log.Println("Starting token lifecycle management for accessor " + secret.Auth.Accessor)
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
			log.Printf("Successfully renewed token accessor " + renewal.Secret.Auth.Accessor + " at: " + renewal.RenewedAt.String())
		}
	}
}

func (v *Vault) RenewSecret(secret Secret) error {
	renewer, err := client.NewRenewer(&RenewerInput{
		Secret: &secret,
		//Grace:  time.Duration(15 * time.Second),
	})

	//Check if we were able to create the renewer
	if err != nil {
		log.Fatal(err)
	}

	//Start the renewer
	log.Println("Starting secret lifecycle management for lease " + secret.LeaseID)
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
			log.Printf("Successfully renewed secret lease " + renewal.Secret.LeaseID + " at: " + renewal.RenewedAt.String())
		}
	}
}

func (v *Vault) Encrypt(plaintext string) (string, error) {
	var ciphertext string

	data := map[string]interface{}{"plaintext": plaintext}
	secret, err := client.Logical().Write("/transit/encrypt/order", data)
	if err != nil {
		return "", err
	}

	ciphertext = secret.Data["ciphertext"].(string)
	return ciphertext, nil
}

func (v *Vault) Decrypt(cipher string) (string, error) {
	var plaintext string

	data := map[string]interface{}{"ciphertext": cipher}
	secret, err := client.Logical().Write("/transit/decrypt/order", data)
	if err != nil {
		return "", err
	}

	plaintext = secret.Data["plaintext"].(string)
	return plaintext, nil
}

func (v *Vault) Close() {
	client.Auth().Token().RevokeSelf(client.Token())
}
