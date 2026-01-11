################################# Login script ################################

:if ([/system script find name="Auto-Login-KMITL"] != "") do={
  /system script set "Auto-Login-KMITL" name="AutoLogin-Login"; # rename old
}
:if ([/system script find name="AutoLogin-Login"] = "") do={
  /system script add name="AutoLogin-Login";
}
/system script set "AutoLogin-Login" policy=policy,read,test,write source={
  :log debug "[Auto-Login] Logging in...";
  
  # Ensure utilities are loaded
  global ParseJSON;
  local isRunUtility false;
  if (!any $ParseJSON) do={
    /system script run "AutoLogin-Utility";
    :set isRunUtility true;
  }

  # Load Config
  :local config [:parse (":return {" . [/system script get AutoLogin-Config source] . "};")]
  :local account [$config];
  
  # Resolve Server IP
  :local serverIP;
  :do {
    :set serverIP [:resolve portal.kmitl.ac.th];
  } on-error={
    # Fallback DNS
    :set serverIP [:resolve server=1.1.1.1 portal.kmitl.ac.th];
  }

  # Prepare Payload
  :local macRaw [/interface ethernet get [/interface ethernet find default-name=ether1] mac-address];
  :local umac ([:pick $macRaw 0 2] . [:pick $macRaw 3 5] . [:pick $macRaw 6 8] . [:pick $macRaw 9 11] . [:pick $macRaw 12 14] . [:pick $macRaw 15 17]);
  :local acip "10.252.13.10";
  :local data "userName=$($account->"username")&userPass=$($account->"password")&uaddress=$($account->"ipaddress")&umac=$umac&agreed=1&acip=$acip&authType=1";
  :local url "https://portal.kmitl.ac.th:19008/portalauth/login";

  # Execute Login
  :local content;
  :do {
    :set content ([/tool fetch http-method=post http-data=$data url=$url as-value output=user]->"data");
  } on-error={
    :log error "[Auto-Login] Network Error - Could not connect to authentication server. Check logs for details.";
    :return false;
  }

  # Verify Success
  :if ([$ParseJSON $content "success"] = false) do={
    :log error "[Auto-Login] Can not login... server-msg: $[$ParseJSON $content "message"]";
    :return false;
  }

  :log info "[Auto-Login] Login Successful.";

  # Set scheduler for heartbeat and AutoReLogin
  /system scheduler set "AutoLogin-AutoReLogin" start-date=[/system clock get date] start-time=[/system clock get time];

  if ($isRunUtility) do={
    global UnloadUtil; $UnloadUtil;
  }

  :return true;
};

################################ Utility script ###############################

:if ([/system script find name="AutoLogin-Utility"] = "") do={
  /system script add name="AutoLogin-Utility";
}
/system script set "AutoLogin-Utility" policy=policy,read,test,write source={
  :global CheckConnection do={
    :local googleIP;
    :do {
      :set googleIP [:resolve server=1.1.1.1 www.google.com];
    } on-error={
      :log warning "[Auto-Login] No Internet (DNS Resolution Failed)...";
      :return "noInternet";
    }

    # Detect captive portal via generate_204 check
    :local detect;
    :do {
       :set detect ([/tool fetch url="http://$googleIP/generate_204" as-value output=user]->"data");
    } on-error={
       # If fetch fails completely, likely no internet or blocked
       :return "notLogin";
    }

    :if ($detect = "") do={
      :return "logged-in";
    } else={
      :return "notLogin";
    }
  }

  :global ParseJSON do={
    :local json;
    :do {
      :set json [:deserialize from=json value=$1];
    } on-error={
      :return [];
    }
    :return ($json->$2);
  }

  :global UnloadUtil do={
    global CheckConnection; set CheckConnection;
    global ParseJSON; set ParseJSON;
    global UnloadUtil; set UnloadUtil;
  }
}

############################# AutoStart scheduler #############################

:if ([/system scheduler find name="AutoLogin-AutoStart"] = "") do={
  /system scheduler add name="AutoLogin-AutoStart";
}
/system scheduler set "AutoLogin-AutoStart" start-time=startup policy=policy,read,test,write on-event={
  :delay 10s;
  :log debug "[Auto-Login] Startup check...";
  /system script run "AutoLogin-Utility";
  global CheckConnection;
  
  :while ([$CheckConnection] = "noInternet") do={
    :delay 3s;
    :log debug "[Auto-Login] Waiting for network link...";
  }

  /system script run "AutoLogin-Login";
  global UnloadUtil; $UnloadUtil;
};

############################ AutoReLogin scheduler ############################

:if ([/system scheduler find name="AutoLogin-AutoReLogin"] = "") do={
  /system scheduler add name="AutoLogin-AutoReLogin";
}
/system scheduler set "AutoLogin-AutoReLogin" interval=[:totime "09h00m00s"] policy=policy,read,test,write on-event={
  :log debug "[Auto-Login] Checking session status...";
  /system script run "AutoLogin-Utility";
  global CheckConnection;
  :local loop 0;
  
  :do {
    :local internet [$CheckConnection];
    :if ($internet = "noInternet") do={
      global UnloadUtil; $UnloadUtil;
      :return false;
    }
    :if ($internet = "notLogin") do={
      :set loop 200; # Break loop
    } else={
      :log debug "[Auto-Login] Internet accessible. Re-checking in 1s...";
      :set loop ($loop + 1);
      :delay 1s;
    }
  } while=($loop < 10);

  :if ($loop != 200) do={
    :log warning "[Auto-Login] Session timeout reached but internet still works. Skipping login.";
    global UnloadUtil; $UnloadUtil;
    :return false;
  }

  /system script run "AutoLogin-Login";
  global UnloadUtil; $UnloadUtil;
};

############################# Heartbeat scheduler #############################
:if ([/system scheduler find name="AutoLogin-Hearbeat"] != "") do={
  /system scheduler set "AutoLogin-Hearbeat" name="AutoLogin-Heartbeat";
}
:if ([/system scheduler find name="AutoLogin-Heartbeat"] = "") do={
  /system scheduler add name="AutoLogin-Heartbeat";
}
/system scheduler set "AutoLogin-Heartbeat" interval=[:totime "0h01m00s"] policy=policy,read,test,write on-event={
  /system script run "AutoLogin-Utility";
  global CheckConnection; 
  global ParseJSON;
  
  :if ([$CheckConnection] = "notLogin") do={
    :log warning "[Auto-Login] Lost Connection (Heartbeat check). Retrying login...";
    /system script run "AutoLogin-Login";
  } else={
    # Prepare Config
    :local config [:parse (":return {" . [/system script get AutoLogin-Config source] . "};")]
    :local account [$config];
    
    :local url "https://nani.csc.kmitl.ac.th/network-api/data/";
    :local data "username=$($account->"username")&os=Chrome v116.0.5845.141 on Windows 10 64-bit&speed=1.29&newauth=1";
    :local content;

    :do {
      :set content ([/tool fetch http-method=post http-data=$data url=$url as-value output=user]->"status");
    } on-error={
      :log warning "[Auto-Login] HeartBeat Network Error.";
      /system script run "AutoLogin-Login";
      :return nil;
    }
    
    :if ($content = "finished") do={
      :log debug "[Auto-Login] HeartBeat OK.";
    } else={
      :log error "[Auto-Login] HeartBeat Failed (Status: $content).";
      /system script run "AutoLogin-Login";
    }
  }

  global UnloadUtil; $UnloadUtil;
};

############################### Setup New Script ##############################
:if ([/system script find name="AutoLogin-Config"] = "") do={
  global loginUser; global loginPass; global loginIP;
  :if (!any $loginUser || !any $loginPass) do={
    :local input do={
      :local out "";
      :local mask "";
      :local in "";
      :local ascii " !\"#\$%&'()*+,-./0123456789:;<=>\?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~";
      :if (!any $1) do={
        :set $1 "enter text";
      }
      :put "$1 : ";
      :do {
        /terminal cuu count=1;
        /terminal el;
        :if ($2 = true) do={
          :put "$1 : $mask";
        } else={
          :put "$1 : $out";
        }
        :set in [/terminal inkey timeout=60];
        :if (32 <= $in && $in < 128) do={
          :local char [:pick $ascii ($in-32)]
          :set out ($out . $char);
          :set mask ($mask . "*");
        } else={
          if ($in = 8) do={
            :set out [:pick $out 0 ([:len $out] - 1)]
            :set mask [:pick $mask 0 ([:len $mask] - 1)]
          }
        }
      } while=(in != 13); # enter
      :return $out
    };

    :put "Please enter your username and password to use auto-login";
    :put "Do not enter @kmitl.ac.th in username"
    :set loginUser [$input "Username"];
    :set loginPass [$input "Password" true];
    :set loginIP [$input "IP"];
  }
  /system script add name="AutoLogin-Config" dont-require-permissions=yes source="username=\"$loginUser\";\r\npassword=\"$loginPass\";\r\nipaddress=\"$loginIP\";";
  set loginUser; set loginPass; set loginIP;
}

/system script run "AutoLogin-Utility";
:global CheckConnection;
:local internet [$CheckConnection];
:if ($internet = "notLogin") do={
  :put "Let's login. (Watch status in log)";
  /system script run "AutoLogin-Login";
} else={
  :if ($internet = "logged-in") do={
    :put "Now internet is accessible, Do you want to re-login (y/N)";
    :local in [/terminal inkey timeout=60];
    :if (($in %32) = 25) do={
      :put "Let's login. (Watch status in log)";
      /system script run "AutoLogin-Login";
    }
  }
}
global UnloadUtil; $UnloadUtil;

:put "Finish setup";
