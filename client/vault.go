package client

import (
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io/ioutil"
	"log"
	"time"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/credentials/stscreds"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/sts"
	. "github.com/hashicorp/vault/api"
	"golang.org/x/net/context"
	"golang.org/x/oauth2/google"
	"google.golang.org/api/iam/v1"
)

type Vault struct {
	Host           string
	Port           string
	Scheme         string
	Authentication string
	Credential     string
	Role           string
	Mount          string
}

var client *Client

func (v *Vault) Init() error {
	var err error
	var renew bool
	var token string

	//Default client
	config := DefaultConfig()
	client, err = NewClient(config)
	//Set the address
	err = client.SetAddress(fmt.Sprintf("%s://%s:%s", v.Scheme, v.Host, v.Port))
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
			log.Println("Got token from config file")
			token = v.Credential
		} else {
			log.Fatal("Could not get Vault token.")
		}
		client.SetToken(token)
	case "kubernetes":
		log.Println("Using kubernetes authentication")

		//Check Mount
		if len(v.Mount) == 0 {
			return errors.New("Auth mount not in config.")
		}
		log.Printf("Mount: auth/%s", v.Mount)

		//Check Role
		if len(v.Role) == 0 {
			return errors.New("K8s role not in config.")
		}
		log.Printf("Role: %s", v.Role)

		//Check SA
		if len(v.Credential) == 0 {
			return errors.New("K8s SA file not in config.")
		}
		log.Printf("SA: %s", v.Credential)

		//Get the JWT from POD
		jwt, err := ioutil.ReadFile(v.Credential)
		if err != nil {
			return err
		}

		//Auth with K8s vault
		data := map[string]interface{}{"jwt": string(jwt), "role": v.Role}
		secret, err := client.Logical().Write(fmt.Sprintf("auth/%s/login", v.Mount), data)
		if err != nil {
			return err
		}

		//Set client token
		log.Printf("Metadata: %v", secret.Auth.Metadata)
		token = secret.Auth.ClientToken
		client.SetToken(token)
	case "aws":
		var svc *sts.STS

		log.Println("Using AWS authentication")

		//Check Mount
		if len(v.Mount) == 0 {
			return errors.New("Auth mount not in config.")
		}
		log.Printf("Mount: auth/%s", v.Mount)

		//Check Role
		if len(v.Role) == 0 {
			return errors.New("AWS role not in config.")
		}
		log.Printf("Role: %s", v.Role)

		//Get a session
		loginData := make(map[string]interface{})
		stsSession := session.Must(session.NewSession())

		//If we have a creds/sa var we will try to assume it.
		//If not we will create an STS session with our default creds.
		if len(v.Credential) > 0 {
			log.Printf("SA: %s", v.Credential)
			creds := stscreds.NewCredentials(stsSession, v.Credential)
			svc = sts.New(stsSession, &aws.Config{Credentials: creds})
		} else {
			svc = sts.New(stsSession)
		}

		//Sign the STS request
		var params *sts.GetCallerIdentityInput
		stsRequest, _ := svc.GetCallerIdentityRequest(params)
		stsRequest.Sign()

		//Get headers
		headersJson, err := json.Marshal(stsRequest.HTTPRequest.Header)
		if err != nil {
			log.Fatal(err)
		}
		requestBody, err := ioutil.ReadAll(stsRequest.HTTPRequest.Body)
		if err != nil {
			log.Fatal(err)
		}

		//Construct payload
		loginData["iam_http_request_method"] = stsRequest.HTTPRequest.Method
		loginData["iam_request_url"] = base64.StdEncoding.EncodeToString([]byte(stsRequest.HTTPRequest.URL.String()))
		loginData["iam_request_headers"] = base64.StdEncoding.EncodeToString(headersJson)
		loginData["iam_request_body"] = base64.StdEncoding.EncodeToString(requestBody)
		loginData["role"] = v.Role

		//Login
		path := fmt.Sprintf("auth/%s/login", v.Mount)
		secret, err := client.Logical().Write(path, loginData)
		if err != nil {
			log.Fatal(err)
		}
		if secret == nil {
			log.Fatal("empty response from credential provider")
		}

		//Set client token
		log.Printf("Metadata: %v", secret.Auth.Metadata)
		token = secret.Auth.ClientToken
		client.SetToken(token)
	case "gcp":
		log.Println("Using GCP authentication")

		//Check Mount
		if len(v.Mount) == 0 {
			return errors.New("Auth mount not in config.")
		}
		log.Printf("Mount: auth/%s", v.Mount)

		//Check Role
		if len(v.Role) == 0 {
			return errors.New("GCP role not in config.")
		}
		log.Printf("Role: %s", v.Role)

		//Check SA
		if len(v.Credential) == 0 {
			return errors.New("GCP SA not in config.")
		}
		log.Printf("SA: %s", v.Credential)

		//Set up client
		ctx := context.Background()

		//Client and service
		oauthClient, err := google.DefaultClient(ctx, iam.CloudPlatformScope)
		iamService, err := iam.New(oauthClient)

		//Sign JWT
		serviceAccount := v.Credential
		resourceName := fmt.Sprintf("projects/%s/serviceAccounts/%s", "-", serviceAccount)
		jwtPayload := map[string]interface{}{
			"aud": fmt.Sprintf("vault/%s", v.Role),
			"sub": serviceAccount,
			"exp": time.Now().Add(time.Minute * 10).Unix(),
		}

		//Payload
		payloadBytes, err := json.Marshal(jwtPayload)
		if err != nil {
			log.Fatal(err)
		}
		signJwtReq := &iam.SignJwtRequest{
			Payload: string(payloadBytes),
		}

		//Response
		resp, err := iamService.Projects.ServiceAccounts.SignJwt(resourceName, signJwtReq).Do()
		if err != nil {
			log.Fatal(err)
		}

		//Login
		secret, err := client.Logical().Write(
			fmt.Sprintf("auth/%s/login", v.Mount),
			map[string]interface{}{
				"role": v.Role,
				"jwt":  resp.SignedJwt,
			})
		if err != nil {
			log.Fatal(err)
		}

		//Set client token
		log.Printf("Metadata: %v", secret.Auth.Metadata)
		token = secret.Auth.ClientToken
		client.SetToken(token)
	default:
		log.Fatalf("Auth method %s is not supported", v.Authentication)
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
	if renew == true {
		go v.RenewToken()
	}

	return nil
}

func (v *Vault) GetSecret(path string) (Secret, error) {
	log.Printf("Getting secret: %s", path)
	secret, err := client.Logical().Read(path)
	if err != nil {
		return Secret{}, err
	}
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
	log.Printf("Starting token lifecycle management for accessor: %s", secret.Auth.Accessor)
	go renewer.Renew()
	defer renewer.Stop()

	//Log it
	for {
		select {
		case err := <-renewer.DoneCh():
			if err != nil {
				log.Fatal(err)
			}
			//App will terminate after token cannot be renewed.
			log.Fatalf("Cannot renew token with accessor %s. App will terminate.", secret.Auth.Accessor)
		case renewal := <-renewer.RenewCh():
			log.Printf("Successfully renewed token accessor: %s", renewal.Secret.Auth.Accessor)
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
	log.Printf("Starting secret lifecycle management for lease: %s", secret.LeaseID)
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
			log.Fatalf("Cannot renew %s. App will terminate.", secret.LeaseID)
		case renewal := <-renewer.RenewCh():
			log.Printf("Successfully renewed secret lease: %s", renewal.Secret.LeaseID)
		}
	}
}

func (v *Vault) Encrypt(path string, plaintext string) (string, error) {
	var ciphertext string

	data := map[string]interface{}{"plaintext": plaintext}
	secret, err := client.Logical().Write(path, data)
	if err != nil {
		return "", err
	}

	ciphertext = secret.Data["ciphertext"].(string)
	return ciphertext, nil
}

func (v *Vault) Decrypt(path string, ciphertext string) (string, error) {
	var plaintext string

	data := map[string]interface{}{"ciphertext": ciphertext}
	secret, err := client.Logical().Write(path, data)
	if err != nil {
		return "", err
	}

	plaintext = secret.Data["plaintext"].(string)
	return plaintext, nil
}

func (v *Vault) Close() {
	client.Auth().Token().RevokeSelf(client.Token())
}
