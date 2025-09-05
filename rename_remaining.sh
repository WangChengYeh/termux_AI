#!/bin/bash

# Script to rename remaining DNS/Kerberos executables
cd /Users/wangchengye/Documents/GitHub/termux_AI/app/src/main/jniLibs/arm64-v8a

# DNS utilities
REMAINING_EXECUTABLES=(
    "libdrill.so:drill.so"
    "libdig.so:dig.so" 
    "libnslookup.so:nslookup.so"
    "libhost.so:host.so"
    "libdelv.so:delv.so"
    "libnsupdate.so:nsupdate.so"
    "libarpaname.so:arpaname.so"
    "libmdig.so:mdig.so"
    "libnamed.so:named.so"
    "librndc.so:rndc.so"
    "librndc-confgen.so:rndc-confgen.so"
    "libddns-confgen.so:ddns-confgen.so"
    "libtsig-keygen.so:tsig-keygen.so"
    "libnamed-checkconf.so:named-checkconf.so"
    "libnamed-checkzone.so:named-checkzone.so"
    "libnamed-compilezone.so:named-compilezone.so"
    "libnamed-journalprint.so:named-journalprint.so"
    "libnamed-rrchecker.so:named-rrchecker.so"
    "libdnssec-keygen.so:dnssec-keygen.so"
    "libdnssec-signzone.so:dnssec-signzone.so"
    "libdnssec-verify.so:dnssec-verify.so"
    "libdnssec-dsfromkey.so:dnssec-dsfromkey.so"
    "libdnssec-keyfromlabel.so:dnssec-keyfromlabel.so"
    "libdnssec-revoke.so:dnssec-revoke.so"
    "libdnssec-settime.so:dnssec-settime.so"
    "libdnssec-importkey.so:dnssec-importkey.so"
    "libdnssec-cds.so:dnssec-cds.so"
    "libdnssec-ksr.so:dnssec-ksr.so"
    "libnsec3hash.so:nsec3hash.so"
    
    # Kerberos utilities (if they exist)
    "libkproplog.so:kproplog.so"
    "libkrb5kdc.so:krb5kdc.so"
    "libgss-server.so:gss-server.so"
    "libktutil.so:ktutil.so"
    "libuuclient.so:uuclient.so"
    "libsserver.so:sserver.so"
    "libkprop.so:kprop.so"
    "libkadmin.local.so:kadmin.local.so"
    "libkinit.so:kinit.so"
    "libkdb5_util.so:kdb5_util.so"
    "libkpropd.so:kpropd.so"
    "libsim_server.so:sim_server.so"
    "libkpasswd.so:kpasswd.so"
    "libkdestroy.so:kdestroy.so"
    "libkvno.so:kvno.so"
    "libkadmind.so:kadmind.so"
    "libgss-client.so:gss-client.so"
    "libuuserver.so:uuserver.so"
    "libksu.so:ksu.so"
    "libsclient.so:sclient.so"
    "libkswitch.so:kswitch.so"
    "libkadmin.so:kadmin.so"
    "libsim_client.so:sim_client.so"
    "libklist.so:klist.so"
)

echo "Renaming remaining executables..."
echo "================================="

for rename_pair in "${REMAINING_EXECUTABLES[@]}"; do
    OLD_NAME="${rename_pair%%:*}"
    NEW_NAME="${rename_pair##*:}"
    
    if [[ -f "$OLD_NAME" ]]; then
        echo "Renaming: $OLD_NAME -> $NEW_NAME"
        mv "$OLD_NAME" "$NEW_NAME"
    else
        echo "Warning: $OLD_NAME not found"
    fi
done

echo "Done!"