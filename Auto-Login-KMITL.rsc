# spell-checker:words totime tonum kmitl mikrotik

################################# Login script ################################
# spell-checker:ignore JSESSIONID Heatbeat
:if ([/system script find name="Auto-Login-KMITL"] != "") do={
  /system script set "Auto-Login-KMITL" name="AutoLogin-Login"; # rename old
}
:if ([/system script find name="AutoLogin-Login"] = "") do={
  /system script add name="AutoLogin-Login";
}
/system script set "AutoLogin-Login" policy=policy,read,test,write source={
:log debug "Auto-Login: Logging in...";
global ParseJSON;
local isRunUtility false;
if (!any $ParseJSON) do={
  /system script run "AutoLogin-Utility";
  :set isRunUtility true;
}
:local config [:parse (":return {" . [/system script get AutoLogin-Config source] . "};")]
:local account [$config];
:local serverIP;
# https://portal.kmitl.ac.th:19008/portalauth/login
:do {
  :set serverIP [:resolve portal.kmitl.ac.th];
} on-error={
  # when use DoH and not login yet, will no dns record in cache and can not query new
  :set serverIP [:resolve server=1.1.1.1 portal.kmitl.ac.th];
}
:local data "userName=$($account->"username")&userPass=$($account->"password")&uaddress=$($account->"ipaddress")&umac=7486e2507746&agreed=1&acip=10.252.13.10&authType=1";
:local url "https://portal.kmitl.ac.th:19008/portalauth/login";
:local content ([/tool fetch http-method=post http-data=$data url=$url host="portal.kmitl.ac.th:19008" as-value output=user]->"data");

:if ([$ParseJSON $content "success" true] = false) do={
  :log error "Auto-Login: Can not login... server-msg: $[$ParseJSON $content "message" true]";
  :return false;
}

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
    :log warning "Auto-Login: No Internet...";
    :return "noInternet";
  }

  # detect web portal
  :local detect ([/tool fetch url="http://$googleIP/generate_204" as-value output=user]->"data");

  :if ($detect = "") do={
    :return "logged-in";
  } else={
    :return "notLogin";
  }
}

:global ParseJSON do={
  :local start 0;
  :if ($3 = true) do={
    :if ([:pick $1 8] = "{") do={
      :set start ([:find $1 "}"]);
    } else={
      :if ([:pick $1 8] = "[") do={
        :set start ([:find $1 "]"]);
      }
    }
  }
  :set start ([:find $1 $2 $start] + [:len $2] + 2);
  :local end [:find $1 "," $start];
  :if ([:pick $1 ($end-1)] = "}") do={
    :set end ($end-1);
  }
  :local out [:pick $1 $start $end];
  :if ([:pick $out] = "\"") do={
    :return [:pick $1 ($start+1) ($end-1)];
  }
  :if ($out = "null") do={
    :return [];
  }
  :if ($out = "true") do={
    :return true;
  }
  :if ($out = "false") do={
    :return false;
  }
  :if ($out ~ "^[0-9.+-]+\$") do={
    :return [:tonum $out];
  }
  :put "Cannot Parse JSON object";
  :return [];
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
:log debug "Auto-Login: startup...";
/system script run "AutoLogin-Utility";
global CheckConnection;
:while ([$CheckConnection] = "noInternet") do={
  :delay 3s;
  :log debug "Auto-Login: Run Check connection...";
}

/system script run "AutoLogin-Login";
global UnloadUtil; $UnloadUtil;
};

############################ AutoReLogin scheduler ############################

:if ([/system scheduler find name="AutoLogin-AutoReLogin"] = "") do={
  /system scheduler add name="AutoLogin-AutoReLogin";
}
/system scheduler set "AutoLogin-AutoReLogin" interval=[:totime "09h00m00s"] policy=policy,read,test,write on-event={
:log debug "Auto-Login: Will check connection and re-login when login session timeout...";
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
    :set loop 200;
  } else={
    :log debug "Auto-Login: Recheck connection...";
    :set loop ($loop + 1);
  }
} while=($loop < 10);

:if ($loop != 200) do={
  :log warning "Auto-Login: Wait for session timeout is timeout. Not login...";
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
global CheckConnection; global ParseJSON;
:if ([$CheckConnection] = "notLogin") do={
  :log warning "Auto-Login: Lost Connection, Retry login...";
  /system script run "AutoLogin-Login";
} else={
    :local config [:parse (":return {" . [/system script get AutoLogin-Config source] . "};")]
    :local account [$config];
    
    :local url "https://nani.csc.kmitl.ac.th/network-api/data/";
    :local data "username=64010899&os=Chrome v116.0.5845.141 on Windows 10 64-bit&speed=1.29&newauth=1";

    :local content ([/tool fetch http-method=post http-data=$data url=$url host="nani.csc.kmitl.ac.th" as-value output=user]->"status");
    
   
    :if ($content = "finished") do={
      :log info "Auto-Login: HeartBeat OK...";
    } else={
      :log error "Auto-Login: HeartBeat ERROR...";
      /system script run "AutoLogin-Login";
    }

    # Delete the response file
    /file remove response.txt
}

global UnloadUtil; $UnloadUtil;
};


############################# remove old variable #############################
# spell-checker:ignore Lcheck Lhearbeat Linit Llogin
global LcheckConnection; set LcheckConnection;
global Lhearbeat; set Lhearbeat;
global Linit; set Linit;
global Llogin; set Llogin;
global LloginLoop; set LloginLoop;
global loginServer; set loginServer;
global JSONUnload; $JSONUnload; set JSONUnload;

############################### setup new script ##############################
# spell-checker:ignore dont abcdefghijklmnopqrstuvwxyz inkey
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