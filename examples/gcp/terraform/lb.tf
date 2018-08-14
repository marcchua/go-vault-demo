module "go-gce-lb" {
  source            = "github.com/GoogleCloudPlatform/terraform-google-lb-http"
  name              = "go-gce-lb"
  target_tags       = ["go-gce-apps"]
  backends          = {
    "0" = [
      { group = "${google_compute_instance_group_manager.gce_group_manager.instance_group}" }
    ],
  }
  backend_params    = [
    # health check path, port name, port number, timeout seconds.
    "/health,go,3000,10"
  ]
}


module "go-iam-lb" {
  source            = "github.com/GoogleCloudPlatform/terraform-google-lb-http"
  name              = "go-iam-lb"
  target_tags       = ["go-iam-apps"]
  backends          = {
    "0" = [
      { group = "${google_compute_instance_group_manager.iam_group_manager.instance_group}" }
    ],
  }
  backend_params    = [
    # health check path, port name, port number, timeout seconds.
    "/health,go,3000,10"
  ]
}
