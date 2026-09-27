# Catalog of ZITADEL applications to create via the ZITADEL Terraform
# provider (https://registry.terraform.io/providers/zitadel/zitadel/latest),
# migrated from the Lodge104 Auth0 tenant (lodge104.auth0.com). Consumed by
# the zitadel-resources unit in each env (prod/dev/test) via
# _modules/zitadel-resources.
#
# This catalog was built by enumerating every application in the Auth0
# tenant (via the Auth0 Management API) and classifying each by its Auth0
# app_type / token_endpoint_auth_method into the closest ZITADEL application
# type:
#   - regular_web, confidential (client_secret_post)  -> zitadel_application_oidc, OIDC_APP_TYPE_WEB, OIDC_AUTH_METHOD_TYPE_BASIC
#   - regular_web/spa, public (token_endpoint_auth_method = none)   -> zitadel_application_oidc, OIDC_APP_TYPE_WEB or OIDC_APP_TYPE_USER_AGENT, OIDC_AUTH_METHOD_TYPE_NONE
#   - non_interactive (machine-to-machine, client_credentials only) -> zitadel_application_api
#
# Excluded (Auth0-internal tenant artifacts, not real applications to
# migrate): "API Explorer Application" (Management API test client),
# "auth0-authz", "logs-to-cloudwatch", "auth0-account-link" (internal Auth0
# extensions), "All Applications" (Auth0's tenant-wide global client), "2FA"
# (Auth0 Guardian passwordless enrollment page).
#
# Deferred (SAML service-provider integrations -- "AWS", "AWS WorkSpaces",
# "Google Workspace" in Auth0, all using the samlp addon): the ZITADEL
# Terraform provider's zitadel_application_saml resource requires either
# metadata_xml or a reachable metadata_url for the specific SAML Service
# Provider, which is SP-specific (e.g. AWS's per-account ACS URL /
# audience). These need to be hand-verified against each target SP's actual
# SAML metadata before being added here, so they are intentionally NOT
# included yet. Add them as zitadel_application_saml entries once that
# metadata is collected.
locals {
  # Organization these migrated applications are created under -- the
  # council/lodge that owns them, not an "Auth0 Migration" label.
  org_name     = "Occoneechee Lodge"
  project_name = "Auth0 Migration"

  # ---------------------------------------------------------------------------
  # Confidential OIDC web applications (server-side apps holding a client
  # secret). auth_method_type = OIDC_AUTH_METHOD_TYPE_BASIC matches Auth0's
  # "client_secret_post" (both are secret-based; BASIC is the ZITADEL
  # default and works equally well over HTTPS).
  # ---------------------------------------------------------------------------
  oidc_web_apps = {
    training = {
      name                      = "Training"
      redirect_uris             = ["https://training.lodge104.net/admin/oauth2callback.php"]
      post_logout_redirect_uris = ["https://training.lodge104.net"]
    }
    trading_post = {
      name = "Trading Post"
      redirect_uris = [
        "https://store.lodge104.net/index.php?auth0=1",
        "https://app07.lodge104.net/index.php?auth0=1",
      ]
      post_logout_redirect_uris = [
        "https://store.lodge104.net",
        "https://store.lodge104.net/wp-login.php",
      ]
    }
    noac_portal = {
      name = "NOAC Portal"
      redirect_uris = [
        "https://app12.lodge104.net/",
        "https://noac.lodge104.net/",
      ]
      post_logout_redirect_uris = [
        "https://app12.lodge104.net/",
        "https://noac.lodge104.net/",
      ]
    }
    support = {
      name                      = "Support"
      redirect_uris             = ["https://support.lodge104.net/api/auth/oauth2"]
      post_logout_redirect_uris = ["https://support.lodge104.net"]
    }
    wordpress = {
      name = "WordPress"
      redirect_uris = [
        "https://lodge104.net/index.php?auth0=1",
        "https://test.wp.lodge104.net/index.php?auth0=1",
        "https://prod.wp.lodge104.net/index.php?auth0=1",
      ]
      post_logout_redirect_uris = [
        "https://lodge104.net",
        "https://lodge104.net/wp-login.php",
        "https://test.wp.lodge104.net/wp-login.php",
        "https://prod.wp.lodge104.net/wp-login.php",
      ]
    }
    survey = {
      name                      = "Survey"
      redirect_uris             = ["http://survey.lodge104.net/index.php?r=admin/authentication/sa/login"]
      post_logout_redirect_uris = []
    }
    support_forum = {
      name = "Support Forum"
      redirect_uris = [
        "https://support-test.lodge104.net/auth/auth0",
        "https://support.lodge104.net/auth/auth0",
      ]
      post_logout_redirect_uris = []
    }
    docs = {
      name                      = "Docs"
      redirect_uris             = ["https://docs.lodge104.net/login/97e8a9cb-215e-4cac-b04c-814160d0d3f2/callback"]
      post_logout_redirect_uris = ["https://docs.lodge104.net"]
    }
    matomo = {
      name = "Matomo"
      redirect_uris = [
        "https://analytics.lodge104.net/index.php?module=LoginOIDC&action=callback&provider=oidc",
        "https://www.analytics.lodge104.net/index.php?module=LoginOIDC&action=callback&provider=oidc",
      ]
      post_logout_redirect_uris = [
        "https://analytics.lodge104.net",
        "https://www.analytics.lodge104.net",
      ]
    }
  }

  # ---------------------------------------------------------------------------
  # Public OIDC applications (no client secret -- PKCE-only). Covers Auth0
  # apps configured with token_endpoint_auth_method = "none" (SPAs, and one
  # regular_web app -- "Insight" -- that Auth0 also had set to public/PKCE).
  # ---------------------------------------------------------------------------
  oidc_public_apps = {
    account = {
      name                      = "Account"
      app_type                  = "OIDC_APP_TYPE_USER_AGENT"
      redirect_uris             = ["http://localhost:4200/"]
      post_logout_redirect_uris = ["http://localhost:4200/"]
    }
    noac = {
      name                      = "NOAC"
      app_type                  = "OIDC_APP_TYPE_USER_AGENT"
      redirect_uris             = ["https://localhost:4200"]
      post_logout_redirect_uris = ["https://localhost:4200"]
    }
    insight = {
      name                      = "Insight"
      app_type                  = "OIDC_APP_TYPE_WEB"
      redirect_uris             = ["https://insight.lodge104.net/oauth2/idpresponse"]
      post_logout_redirect_uris = []
    }
  }

  # ---------------------------------------------------------------------------
  # Machine-to-machine (API) applications -- Auth0 "non_interactive" apps
  # using only the client_credentials grant.
  # ---------------------------------------------------------------------------
  api_apps = {
    account_backend = {
      name             = "Account Back-end"
      auth_method_type = "API_AUTH_METHOD_TYPE_BASIC"
    }
  }
}
