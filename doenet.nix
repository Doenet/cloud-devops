let
  awsKeyId = "AKIAI6QCDKDFAZFL5D5A";
  region = "us-east-2"; # to minimize latency to me
  pkgs = import <nixpkgs> {};
in
{
  network.description = "doenet.cloud";

  resources.ec2KeyPairs.myKeyPair = {
    accessKeyId = awsKeyId;
    inherit region;
  };
  
  resources.ec2SecurityGroups.openPorts = { resources, lib, ... }: {
    accessKeyId = awsKeyId;
    inherit region;
    rules = [
      { toPort = 22; fromPort = 22; sourceIp = "0.0.0.0/0"; } # SSH
      { toPort = 80; fromPort = 80; sourceIp = "0.0.0.0/0"; } # HTTP
      { toPort = 443; fromPort = 443; sourceIp = "0.0.0.0/0"; } # HTTPS
    ];
  };
  
  doenet = { resources, config, nodes, ... }:
  let
    theApiServer = import ../api/default.nix;
    theIdServer = import ../id/default.nix;    
    apiEnvironment = {
      PORT = "4000";
      NODE_ENV = "production";
      TOKEN_SECRET = builtins.readFile ./token-secret.key;
    };
    idEnvironment = {
      PORT = "3000";
      NODE_ENV = "production";
      TOKEN_SECRET = builtins.readFile ./token-secret.key;
      SECRET = builtins.readFile ./secret.key;      
      AUDIENCE_URL_ROOT="https://api.doenet.cloud/";

      SMTP_HOST = "email-smtp.us-east-2.amazonaws.com";
      SMTP_PORT = "465";
      SMTP_USER = "AKIAY4INV4Z4Z23IMXDD";
      SMTP_PASS = builtins.readFile ./smtp.key;
    };    
  in {
    # Cloud provider settings; here for AWS
    deployment.targetEnv = "ec2";
    deployment.ec2.accessKeyId = awsKeyId;
    deployment.ec2.region = region;
    deployment.ec2.instanceType = "t2.medium";
    deployment.ec2.ebsInitialRootDiskSize = 16; # GB
    deployment.ec2.keyPair = resources.ec2KeyPairs.myKeyPair;
    deployment.ec2.associatePublicIpAddress = true;
    deployment.ec2.securityGroups = [ resources.ec2SecurityGroups.openPorts.name ];

    nixpkgs.config.allowUnfree = true;
    environment.systemPackages = with pkgs; [
      pkgs.redis theIdServer theApiServer
    ];
    
    services.redis.enable = true;    
    
    services.nginx = {
      enable = true;

      # Use recommended settings
      recommendedGzipSettings = true;
      recommendedOptimisation = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;

      upstreams."api" = {
        servers = {
          "127.0.0.1:4001" = {};
          "127.0.0.1:4002" = {};
          "127.0.0.1:4003" = {};          
        };
      };

      upstreams."id" = {
        servers = {
          "127.0.0.1:3001" = {};
        };
      };
    };
    
    services.nginx.virtualHosts."id.doenet.cloud" = {
      forceSSL = true;
      enableACME = true;
      root = "${theIdServer}/libexec/@doenet/cloud-id/deps/@doenet/cloud-id/public";
      locations = {
        "/main.css" = {
          tryFiles = "$uri =404";
        };        
        "/" = {
          proxyPass = http://id;
        };
      };
    };

    services.nginx.virtualHosts."api.doenet.cloud" = {
      forceSSL = true;
      enableACME = true;
      root = "${theApiServer}/libexec/@doenet/cloud-api/deps/@doenet/cloud-api/public";
      locations = {
        "/" = {
          proxyPass = http://api;
        };
      };
    };    

    security.acme.acceptTerms = true;
    
    security.acme.certs = {
      "id.doenet.cloud".email = "admin@doenet.cloud";
      "api.doenet.cloud".email = "admin@doenet.cloud";
    };
    
    systemd.services.api1 = {
      description = "api-1 service";
      after = [ "network.target" ];
      wantedBy = [ "default.target" ];
      environment = apiEnvironment // { PORT = "4001"; };
      serviceConfig = {
        ExecStart = "${theApiServer}/bin/doenet-cloud-api";
        User = "doenet";
        Restart = "always";
      };
    };

    systemd.services.api2 = {
      description = "api-2 service";
      after = [ "network.target" ];
      wantedBy = [ "default.target" ];
      environment = apiEnvironment // { PORT = "4002"; };
      serviceConfig = {
        ExecStart = "${theApiServer}/bin/doenet-cloud-api";
        User = "doenet";
        Restart = "always";
      };
    };

    systemd.services.api3 = {
      description = "api-3 service";
      after = [ "network.target" ];
      wantedBy = [ "default.target" ];
      environment = apiEnvironment // { PORT = "4003"; };
      serviceConfig = {
        ExecStart = "${theApiServer}/bin/doenet-cloud-api";
        User = "doenet";
        Restart = "always";
      };
    };
    
    systemd.services.id1 = {
      description = "id-1 service";
      after = [ "network.target" ];
      wantedBy = [ "default.target" ];
      environment = idEnvironment // { PORT = "3001"; };
      serviceConfig = {
        ExecStart = "${theIdServer}/bin/doenet-cloud-id";
        User = "doenet";
        Restart = "always";
      };
    };    
    
    # for "security" do not run the node app as root
    users.extraUsers = {
      doenet = { isNormalUser = true; };
    };
    
    networking.firewall.allowedTCPPorts = [ 80 443 ];
  };
}


