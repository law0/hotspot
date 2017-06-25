## Synopsis

Simple hotspot script allowing to make a wifi hotspot from the computer.
If you have an Ethernet/LAN connection on your computer that you wish to share
via Wifi to other equipment (e.g mobile phone)

## Requirement

This is an init.d script, you need to be root to install it and/or launch it
It requires the following packages/programs:

* hostapd
* dnsmasq
* iptables (normally natively present in most Linux distro)

## How

It uses hostapd for the control of the access point and authentication
You can set the password (WPA2) in the script (yes in clear for now):

```
wpa=2
#wpa_psk=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
wpa_passphrase=my_password_right_here
wpa_key_mgmt=WPA-PSK
wpa_pairwise=CCMP
rsn_pairwise=CCMP

```

Then uses dnsmasq as for DHCP :
```
dnsmasq_args="--interface=wlan0 --except-interface=lo --bind-interfaces --bogus-priv --dhcp-range=10.0.0.101,10.0.0.200,6h --pid-file=${save_place}/dnsmasq_hotspot.pid"
[...]
dnsmasq $dnsmasq_args
```

And finally iptables for nat redirection:
```
iptables -t nat -A POSTROUTING -o $iftarget -s 10.0.0.0/24 -j MASQUERADE
iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i wlan0 -m conntrack --ctstate NEW -j ACCEPT
```

Beforehand, the script saves the original configuration of hostapd and iptables
When turning off the script reverse all it did by applying back these configs :
```
#configure save place
eni="/etc/network/interfaces"
hostapd_conf="/etc/hostapd/hostapd.conf"
save_place="/home/user/bin"

[...]

#saving/copying original confs
cp $eni $save_place/interfaces.save
cp $hostapd_conf $save_place/hostapd.conf.save
iptables-save -c -t filter > $save_place/filter.iptables-save
iptables-save -c -t nat > $save_place/nat.iptables-save

[...]

#do stuff

[...]

#restoring back when turning off
kill -9 $(cat /home/law/bin/dnsmasq_hotspot.pid)
iptables-restore -c < $save_place/filter.iptables-save
iptables-restore -c < $save_place/nat.iptables-save
rm $save_place/filter.iptables-save
rm $save_place/nat.iptables-save
mv $save_place/interfaces.save $eni
rm $save_place/dnsmasq_hotspot.pid
mv $save_place/hostapd.conf.save $hostapd_conf
```

## Tested on:

Debian Jessie 8.8
