# VPN

The quick panel has a VPN tile. It is always visible, and it says which of two
states the machine is in: a tunnel is set up and can be switched, or none is set
up yet.

⚠️ **It used to hide itself when no tunnel existed**, which made "you have not
set one up" and "this desktop cannot do VPN" look identical. That cost a report
asking for a feature that had been there for weeks. The tile stays; what changes
is what it says.

## Why there is no VPN editor in this desktop

NetworkManager already does the work, including WireGuard natively — measured on
NM 1.56, `wireguard` is a connection type and the polkit action
`network-control` already exists, so no root helper of our own is needed.

What this desktop deliberately does **not** ship is a connection editor.
`nm-connection-editor` is on the list of programs left out because they
duplicate our own interface, and a half-built VPN editor would be worse than
either — a VPN whose settings you can half-change is a VPN you cannot trust.

So: connections are created once, on the command line, and switched from the
quick panel from then on. That is the split this desktop uses everywhere —
the panel is for the switch, not for the setup.

## Setting one up

### WireGuard, from a config file

The usual case: your provider or your employer hands you a `.conf`.

```sh
sudo nmcli connection import type wireguard file /path/to/tunnel.conf
```

The connection is named after the file. Check it arrived:

```sh
nmcli connection show --active
nmcli -g NAME,TYPE connection show | grep -i wireguard
```

### OpenVPN, from an .ovpn file

```sh
sudo dnf install NetworkManager-openvpn
sudo nmcli connection import type openvpn file /path/to/tunnel.ovpn
```

⚠️ **The plugin is not installed by default.** Without it the import fails with
a message about an unknown type, which reads like a broken file rather than a
missing package.

### Do not auto-connect

```sh
nmcli connection modify <name> connection.autoconnect no
```

⚠️ **Worth doing deliberately.** A tunnel that comes up on every boot is a
tunnel you stop noticing, and the tile then reports a state you did not choose.
The point of the switch is that it is a switch.

## What the tile does

One press toggles the **first** VPN connection NetworkManager knows about. With
several, the first one wins — this is a switch, not a chooser. If you need to
pick between tunnels, `nmcli connection up <name>` is the way, and the tile then
reports whichever is live.

## Checking it

```sh
nmcli connection show --active        # is it up
ip route get 1.1.1.1                  # does traffic go through it
```

⚠️ **The second command is the one that matters.** A connection listed as active
and a route that still leaves through your ordinary interface is the failure
that looks like success — and it is exactly what a screenshot of the tile cannot
tell you.
