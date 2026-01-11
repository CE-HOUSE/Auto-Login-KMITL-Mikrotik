# KMITL-Auto-Authen-Mikrotik

A **_Mikrotik script_** that let you automatically authenticate into KMITL network.

| :warning: **Disclaimer:** This project is only an experiment on KMITL authentication system and it does not provided a bypass for login system |
| --- |

## Getting started

### Prerequisites

- **Mikrotik RouterOS v7.13 or higher** (Required for native JSON support)
- Internet access via KMITL network

### Installation & Upgrade

1. Login into Mikrotik and open a **New Terminal**.
2. Copy and Paste this script (If use terminal in winbox **Don't use Ctrl-V**, use right click and paste)

```bash
/tool fetch url=https://raw.githubusercontent.com/CE-HOUSE/Auto-Login-KMITL-Mikrotik/main/Auto-Login-KMITL.rsc;
/import file-name=Auto-Login-KMITL.rsc;
```

3. If this is a first-time install, the script will interactively ask for your:
   - **Username** (Student/Staff ID without `@kmitl.ac.th`)
   - **Password** (Masked input)
   - **IP Address** (Your WAN IP)

### Usage

When you run this script, it will create schedulers to handle everything automatically:
- **AutoLogin-AutoStart**: Runs on boot to check connection.
- **AutoLogin-Heartbeat**: Runs every minute to keep the session alive.
- **AutoLogin-AutoReLogin**: periodic check to re-login if session expires (every 9 hours).

You can view logs for more info. Logs from this script start with `[Auto-Login]`.

### Config

You can change your configuration later at **System -> Scripts** and select the script named `AutoLogin-Config`.

|    Name    | Description                                    |
| :--------: | ---------------------------------------------- |
| `username` | Username to login _(without **@kmitl.ac.th**)_ |
| `password` | Password to login                              |
| `ip`       | Public IP                                      |

> **Note on Security:** Your password is stored in the `AutoLogin-Config` script on the router. Ensure only trusted administrators have access to your router configuration.

### Troubleshooting

- **"Conflicting hostnames"**: This issue is fixed in the latest version. Please update the script.
- **"Script Error"**: Ensure you are running RouterOS v7.13+. The script uses modern `:deserialize` commands not available in older versions.
- **Logs**: Check **Log** in WinBox/WebFig for specific error messages (e.g., "Network Error", "Can not login").

## Credit

- **_Member in Network Laboratory_** for [Auto Authen KMITL](https://gitlab.com/networklab-kmitl/auto-authen-kmitl) written in Python language (and some README.md)
- **_[@mayueeeee](https://github.com/mayueeeee)_** for [KMITL-Auto-Authen](https://github.com/mayueeeee/KMITL-Auto-Authen) written in Go language

- **_[@ouoam](https://github.com/ouoam)_** for [KMITL-Auto-Authen-Mikrotik](https://github.com/ouoam/KMITL-Auto-Authen-Mikrotik) written in RSC 

## Tools Used

- **_[Postman](https://www.getpostman.com/)_** - API simulation
- **_[NetCat](https://eternallybored.org/misc/netcat/)_** - Server simulation

## Team
- [@ouoam](https://github.com/ouoam)
- [@BarwSirati](https://github.com/BarwSirati)
- [@CE-HOUSE](https://github.com/CE-HOUSE)