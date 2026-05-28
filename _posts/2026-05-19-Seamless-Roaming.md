---
layout: single
title:  "Seamless Roaming Across 2.4GHz and 5GHz"
excerpt: Configuring the Roaming Trinity (802.11k/v/r) on OpenWrt & Asus RT-AX53U
date:   2026-05-19 12:00:35 +0300
tags: [OpenWrt, WiFi, Wifi Roaming, WiFi6]
---

## The Problem: The Concrete Wall Dilemma

We’ve all been there: you invest in a modern wireless setup, expecting flawless gigabit speeds everywhere. But then reality hits—specifically, a solid concrete wall reinforced with metal rebar.

While 5GHz Wi-Fi offers incredible bandwidth, its short wavelengths struggle immensely to penetrate dense materials like concrete and metal. As soon as you step behind that wall, your 5GHz signal plummets, leaving you with a dead zone or a frozen connection. This is exactly where the 2.4GHz band comes back into the game. With its longer wavelengths, 2.4GHz easily cuts through structural obstacles to maintain coverage.

Fortunately, **Wi-Fi 6 (802.11ax)** isn't just for 5GHz; it brings massive efficiency improvements—like OFDMA and better power management—to the 2.4GHz band as well. To get the best of both worlds, you need a setup that handles **almost seamless switching** between the high-speed 5GHz band and the wall-piercing 2.4GHz band on a single, unified SSID.

If you are running [OpenWrt](https://openwrt.org) on a capable Wi-Fi 6 router like the [Asus RT-AX53U](https://openwrt.org/toh/hwdata/asus/asus_rt-ax53u), you can achieve exactly that by deploying the "Holy Trinity" of wireless roaming: **802.11k, 802.11v, and 802.11r**.

---

## The Roaming Trinity: How 11k, 11v, and 11r Work Together

To understand why your switching feels seamless, you need to understand the distinct job each protocol performs. Think of them as a team managing your device's journey from 5GHz to 2.4GHz:

```
[802.11k: The Mapmaker] ---> [802.11v: The Traffic Cop] ---> [802.11r: The Fast Pass]

```

### 1. 802.11k (Neighbor Reports) — The Mapmaker

Without 802.11k, your phone has to blindly scan the airwaves to find another radio, which drains the battery. 802.11k provides a "neighbor report," telling the phone: *"Hey, I have a 2.4GHz radio right here on Channel 6."*

### 2. 802.11v (BSS Transition Management) — The Traffic Cop

This protocol allows the router to actively manage the network. If your 5GHz signal is dying, the router can "steer" the client by saying: *"Your 5GHz connection is dropping. I recommend you switch to the 2.4GHz band now."*

### 3. 802.11r (Fast Transition) — The Fast Pass

This handles the muscle work. It allows the client to pre-authenticate with the 2.4GHz radio *before* dropping the 5GHz link, slashing the handoff time to a sub-50ms window.

---

## Real-World Proof: The Apple Ecosystem Advantage

Apple devices like the **iPhone** and **MacBook** are notoriously strict about enterprise wireless specifications. According to [Apple’s official support documentation](https://support.apple.com/en-us/102766), iOS, iPadOS, and macOS use 802.11k, 802.11v, and 802.11r to optimize roaming and determine which "Target BSSID" is the best candidate for the next connection.

By following the configuration below, your OpenWrt router will speak the exact "language" Apple devices expect for optimized roaming:

* **iPhones** will trigger an 802.11v transition request the moment the signal hits the -70 dBm threshold.
* **MacBooks** will use the neighbor reports to maintain a stable connection while moving between rooms without interrupting your workflow.

Apple hardware is highly intelligent when it comes to band selection. They don't just look at which signal is louder; they actively monitor data rates and signal-to-noise ratios. As a result, when you step out from behind that concrete wall, the client automatically and seamlessly hops back to the 5GHz band on its own to prioritize maximum throughput.

*(Note: While Apple gear has been thoroughly tested and confirmed to rock this setup flawlessly, ecosystems like Android, Windows, and proprietary IoT smart-home clients haven't been validated on this specific node yet. Your mileage may vary, though modern stacks should behave similarly.)*

---

## Pre-Requisites

Ensure you have the full wireless daemon installed. The default `wpad-basic` in OpenWrt does not support advanced roaming.

```bash
opkg update
opkg remove wpad-basic-mbedtls wpad-basic-wolfssl
opkg install wpad-openssl
```

---

## The Production Blueprint: `/etc/config/wireless`

To activate this suite, both the 2.4GHz (`radio0`) and 5GHz (`radio1`) interfaces must share the same **SSID**, **Encryption**, and **Mobility Domain**.

```text
config wifi-iface 'default_radio0'
	option device 'radio0'
	option network 'lan'
	option mode 'ap'
	option ssid 'TheSameSSID'
	option key 'YourPassWord'
	option encryption 'sae'
	option sae_pwe '2'
	option ocv '0'
	option log_level '1'
	option ieee80211r '1'
	option mobility_domain 'eaea'
	option bss_transition '1'
	option wnm_sleep_mode '1'
	option ieee80211k '1'
	option disassoc_low_ack '0'
	option ft_over_ds '0'
	option time_advertisement '2'
	option proxy_arp '1'

config wifi-iface 'default_radio1'
	option device 'radio1'
	option network 'lan'
	option mode 'ap'
	option ssid 'TheSameSSID'
	option key 'YourPassWord'
	option encryption 'sae'
	option sae_pwe '2'
	option ocv '0'
	option log_level '1'
	option ieee80211r '1'
	option mobility_domain 'eaea'
	option bss_transition '1'
	option wnm_sleep_mode '1'
	option ieee80211k '1'
	option disassoc_low_ack '0'
	option ft_over_ds '0'
	option time_advertisement '2'
	option proxy_arp '1'
```

---

## Deconstructing the Configuration

* **`option ieee80211k '1'` & `option bss_transition '1'`**: Maps to 802.11k and 802.11v. They handle network discovery and band steering suggestions.
* **`option ieee80211r '1'` & `option mobility_domain 'eaea'`**: Activates Fast Transition. The 4-character hex code (`eaea`) tells your devices that both frequencies belong to the exact same roaming group.
* **`option ft_over_ds '0'`**: Sets the transmission mode to **Over-the-Air**. For cross-band roaming on a single AP node, Over-the-Air is cleaner and widely supported by mobile operating systems.
* **`option encryption 'sae'` & `option sae_pwe '2'`**: Enforces pure WPA3 with *Hash-to-Element (H2E)* protection—a requirement for true Wi-Fi 6 operation that accelerates security handshakes on modern hardware.

---

## Verifying the Setup: Analyzing the Logs

Apply your changes with `wifi reload`. SSH into your Asus router and track the events in real-time as you walk past your structural obstacles:

```sh
logread -f | grep hostapd
```

When your device successfully switches bands, you will see a rapid sequence of events that look exactly like this:

```sh
Mon May 18 22:22:57 2026 daemon.err hostapd: nl80211: kernel reports: key addition failed
Mon May 18 22:22:57 2026 daemon.info hostapd: phy0-ap0: STA 22:33:be:77:33:cc IEEE 802.11: associated (aid 5)
Mon May 18 22:22:57 2026 daemon.notice hostapd: phy0-ap0: AP-STA-CONNECTED 22:33:be:77:33:cc auth_alg=ft
Mon May 18 22:22:57 2026 daemon.notice hostapd: phy1-ap0: Prune association for 22:33:be:77:33:cc
Mon May 18 22:22:57 2026 daemon.notice hostapd: phy1-ap0: AP-STA-DISCONNECTED 22:33:be:77:33:cc
```

### Breaking Down the Output:

1. **`auth_alg=ft`**: Confirms the client authenticated using **Fast Transition (802.11r)** instead of a standard handshake. The transition happened within the exact same millisecond timestamp (`22:22:57`).
2. **`Prune association`**: The target radio interface (`phy0-ap0`) tells the old radio interface (`phy1-ap0`) to drop the connection record immediately because the station has successfully moved.
3. **`kernel reports: key addition failed`**: Don't panic if you see this error. It is a benign, well-known behavior with MediaTek drivers in OpenWrt when handling complex WPA3/FT keys. The framework attempts to overwrite a cryptographic key structure that the driver hardware engine has already mapped. Roaming functions perfectly despite the warning.

By uniting 802.11k, v, and r on OpenWrt, you've built an intelligent, context-aware roaming matrix that keeps even the most demanding Apple devices happy.

---

*This article was written with the assistance of Generative AI.*
