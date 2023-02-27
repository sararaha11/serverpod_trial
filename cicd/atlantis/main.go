package main

import (
	"github.com/runatlantis/atlantis/server/core"
	"github.com/runatlantis/atlantis/server/events"
	"github.com/runatlantis/atlantis/server/logging"
	"github.com/runatlantis/atlantis/server/terraform"
	"github.com/runatlantis/atlantis/server/vcs"
)

func main() {
	// Initialize the server configuration.
	cfg, err := core.DefaultConfig()
	if err != nil {
		logging.Fatal(err.Error())
	}

	// Initialize the VCS client.
	vcsClient, err := vcs.New(cfg.VCS)
	if err != nil {
		logging.Fatal(err.Error())
	}

	// Initialize the Terraform client.
	terraformClient, err := terraform.New(cfg.Terraform)
	if err != nil {
		logging.Fatal(err.Error())
	}

	// Initialize the server and start listening for webhooks.
	server := core.NewServer(cfg, vcsClient, terraformClient)
	webhooks := events.NewWebhooks(server)
	webhooks.Start()
}
