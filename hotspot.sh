### BEGIN INIT INFO
# Provides:          hotpost
# Required-Start:
# Required-Stop:
# Default-Start:     5
# Default-Stop:      0 1 2 3 4 6
# Short-Description: Start hotspot at boot time
# Description:       Allow this computer to be a wifi hotspot.
### END INIT INFO

#!/bin/bash

[ $(id -u) -eq 0 ] || exit

eni="/etc/network/interfaces"
dnsmasq_conf="/etc/dnsmasq.conf"
hostapd_conf="/etc/hostapd/hostapd.conf"
save_place="/home/user/bin"
echo1="echo configuring"
echo2="echo ...Done"

[ -n "$2" ] && gateway="$2" || gateway="192.168.1.1"
[ -n "$3" ] && iftarget="$3" || iftarget="eth0"

turning_on()
{
		[ -n "$(grep hotspot < $eni)" ] && echo "hotspot already on (forgot to turn it off?)" && exit

		$echo1 "interface wlan0"
		cp $eni $save_place/interfaces.save

cat << EOD >> $eni
auto wlan0
iface wlan0 inet static
	address 10.0.0.1
	netmask 255.255.255.0
	gateway $gateway
#hotspot
EOD
		$echo2
		$echo1 "dnsmasq.conf"
		dnsmasq_args="--interface=wlan0 --except-interface=lo --bind-interfaces --bogus-priv --dhcp-range=10.0.0.101,10.0.0.200,6h --pid-file=${save_place}/dnsmasq_hotspot.pid"
#		cp $dnsmasq_conf $save_place/dnsmasq.conf.save

#cat << EOD > $dnsmasq_conf
#interface=wlan0
#bogus-priv
#dhcp-range=10.0.0.101,10.0.0.200,6h
#EOD

		$echo2
		$echo1 "hostapd.conf"
		cp $hostapd_conf $save_place/hostapd.conf.save

cat <<EOD > $hostapd_conf
# interface wlan du Wi-Fi
interface=wlan0

# nl80211 avec tous les drivers Linux mac80211
driver=nl80211

# Nom du spot Wi-Fi
ssid=O.O

# mode Wi-Fi (a = IEEE 802.11a, b = IEEE 802.11b, g = IEEE 802.11g)
hw_mode=g

# canal de fréquence Wi-Fi (1-14)
channel=6

# Wi-Fi ferme
auth_algs=1

wpa=2
#wpa_psk=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
wpa_passphrase=my_password_right_here
wpa_key_mgmt=WPA-PSK
wpa_pairwise=CCMP
rsn_pairwise=CCMP


# Beacon interval in kus (1.024 ms)
beacon_int=100

# DTIM (delivery trafic information message)
dtim_period=2

# Maximum number of stations allowed in station table
max_num_sta=255

# RTS/CTS threshold; 2347 = disabled (default)
rts_threshold=2347

# Fragmentation threshold; 2346 = disabled (default)
fragm_threshold=2346
EOD

		$echo2
		echo "restarting services and configuring firewall"
		service network-manager stop
		ip addr flush dev wlan0
		ifdown wlan0
		ifup wlan0
		echo 1 > /proc/sys/net/ipv4/ip_forward
		service hostapd start
#		service dnsmasq start
		dnsmasq $dnsmasq_args
		iptables-save -c -t filter > $save_place/filter.iptables-save
		iptables-save -c -t nat > $save_place/nat.iptables-save
		iptables -t nat -A POSTROUTING -o $iftarget -s 10.0.0.0/24 -j MASQUERADE
		iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
		iptables -A FORWARD -i wlan0 -m conntrack --ctstate NEW -j ACCEPT
		service network-manager start

		$echo2
}

turning_off()
{
		[ -z "$(grep hotspot < $eni)" ] && echo "hotspot already off" && exit
		echo "moving everything back..."
		echo 0 > /proc/sys/net/ipv4/ip_forward
		ip addr flush dev wlan0
		ifdown wlan0
		service hostapd stop
#		service dnsmasq stop
		kill -9 $(cat /home/law/bin/dnsmasq_hotspot.pid)
		iptables-restore -c < $save_place/filter.iptables-save
		iptables-restore -c < $save_place/nat.iptables-save
		rm $save_place/filter.iptables-save
		rm $save_place/nat.iptables-save
		mv $save_place/interfaces.save $eni
#		mv $save_place/dnsmasq.conf.save $dnsmasq_conf
		rm $save_place/dnsmasq_hotspot.pid
		mv $save_place/hostapd.conf.save $hostapd_conf
		ifup wlan0
		service network-manager restart
		$echo2
}


case "$1" in
	start|reload|restart|force-reload)
		echo "STATUS: currently restarting..."
		echo "STATUS: turning off..."
		turning_off
		echo "STATUS: turning off is done..."
		echo "STATUS: turning on..."
		turning_on
		echo "STATUS: turning on is done!"
		;;
	on)
		turning_on
		;;
	off|stop)
		turning_off
		;;
	status)
		echo status
		;;
	*)
		exit
		;;
esac

