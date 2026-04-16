// Fingerprinting resistance
user_pref("privacy.resistFingerprinting", true);
user_pref("privacy.fingerprintingProtection", true);

// Tracking protection
user_pref("privacy.trackingprotection.enabled", true);
user_pref("privacy.trackingprotection.socialtracking.enabled", true);
user_pref("privacy.trackingprotection.fingerprinting.enabled", true);
user_pref("privacy.trackingprotection.cryptomining.enabled", true);
user_pref("network.cookie.cookieBehavior", 1);

// WebRTC leak fix
user_pref("media.peerconnection.enabled", false);

// DNS leak fix — let VPN handle DNS, disable Firefox's own DoH
user_pref("network.trr.mode", 5);
user_pref("network.dns.disablePrefetch", true);
user_pref("network.prefetch-next", false);

// Telemetry / phoning home
user_pref("toolkit.telemetry.enabled", false);
user_pref("toolkit.telemetry.unified", false);
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("browser.safebrowsing.malware.enabled", false);
user_pref("browser.safebrowsing.phishing.enabled", false);
user_pref("geo.enabled", false);
user_pref("browser.send_pings", false);
user_pref("browser.urlbar.speculativeConnect.enabled", false);

// Session / history
user_pref("privacy.sanitize.sanitizeOnShutdown", true);
user_pref("browser.sessionstore.privacy_level", 2);
