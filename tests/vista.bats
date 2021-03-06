#!/usr/bin/env bats

@test "instance directories and files exist" {
    # Directories
    [ -d /home/${instance} ]
    [ -d /home/${instance}/bin ]
    [ -d /home/${instance}/etc ]
    [ -d /home/${instance}/etc/init.d ]
    [ -d /home/${instance}/etc/xinetd.d ]
    [ -d /home/${instance}/g ]
    [ -d /home/${instance}/r ]
    [ -d /home/${instance}/r/${gtmver} ]
    [ -d /home/${instance}/lib ]
    [ -d /home/${instance}/lib/gtm ]
    [ -d /home/${instance}/log ]
    [ -d /home/${instance}/tmp ]
    [ -d /home/${instance}/www ]

    # Script created files
    [ -e /home/${instance}/bin/disableJournal.sh ]
    [ -e /home/${instance}/bin/enableJournal.sh ]
    [ -e /home/${instance}/bin/prog.sh ]
    [ -e /home/${instance}/bin/removeVistaInstanceMinimal.sh ]
    [ -e /home/${instance}/bin/rotateJournal.sh ]
    [ -e /home/${instance}/bin/rpcbroker.sh ]
    [ -e /home/${instance}/bin/tied.sh ]
    [ -e /home/${instance}/bin/vistalink.sh ]
    [ -e /home/${instance}/etc/db.gde ]
    [ -e /home/${instance}/etc/env ]
    [ -e /home/${instance}/etc/init.d/vista ]
    [ -e /home/${instance}/etc/xinetd.d/vista-rpcbroker ]
    [ -e /home/${instance}/etc/xinetd.d/vista-vistalink ]
    [ -e /home/${instance}/g/${instance}.dat ]
    [ -e /home/${instance}/g/${instance}.gld ]
    [ -e /home/${instance}/g/temp.dat ]

    # This only exists on docker
    [ -e /home/${instance}/bin/start.sh ]
}

@test "GT.M installation exist" {
    # does it exist globally?
    # Only checks key files
    [ -d /opt/lsb-gtm/${gtmver} ]
    [ -e /opt/lsb-gtm/${gtmver}/mumps ]
    [ -e /opt/lsb-gtm/${gtmver}/mupip ]

    # does it exist in the instance?
    [ -e /home/${instance}/lib/gtm/mumps ]
    [ -e /home/${instance}/lib/gtm/mupip ]

}

@test "relink control permissions" {
    gtmrelinkctl=$(ls -1 /home/${instance}/tmp/gtm-relinkctl-*)
    [ -e ${gtmrelinkctl} ]
    [ "$(stat -c %a ${gtmrelinkctl})" -eq "664" ]
}

@test "fifo exists" {
    [ -e /root/fifo ]
}

@test "GT.M install works as intended" {
    # Test the intreperter
    [[ "$(mumps -run %XCMD 'W "Hello World"')" == "Hello World" ]]
    # Test datbase set
    [[ "$(mumps -run %XCMD 'S ^KBBO="Hello World" W ^KBBO K ^KBBO')" == "Hello World" ]]
}

@test "VistA FileMan access works" {
    output=$(mumps -run %XCMD 'S DUZ=.5 D P^DI' << EOF
INQ



EOF
)
    [ $(expr "$output" : ".*Fileman.*") -ne 0 ]
}

@test "RPC Broker connection works" {
    run mumps -run %XCMD 'D HOME^%ZIS W $$TEST^XWBTCPMT("127.0.0.1",9430,1)'
    echo "output :"$output
    [ $(expr "$output" : "1^accept.*") -ne 0 ]
}

@test "VistALink connection works" {
    run yum -y install java
    [ $(expr "$output" : ".*[I,i]nstalled.*") -ne 0 ]
    run java -version
    [ $(expr "$output" : ".*1.8.*") -ne 0 ]
    pushd /tmp
    curl -LO https://github.com/shabiel/vistalink-tester-for-linux/archive/master.zip
    unzip master.zip
    rm -f master.zip
    export CLASSPATH=./geronimo-j2ee-connector_1.5_spec-1.0.1.jar
    export CLASSPATH=${CLASSPATH}:./log4j-1.2.13.jar
    export CLASSPATH=${CLASSPATH}:./vljConnector-1.6.0.028.jar
    export CLASSPATH=${CLASSPATH}:./vljFoundationsLib-1.6.0.028.jar
    export CLASSPATH=${CLASSPATH}:./vljSecurity-1.6.0.028.jar
    export CLASSPATH=${CLASSPATH}:./vljSamples-1.6.0.028.jar
    cd vistalink-tester-for-linux-master/samples-J2SE/
    echo 'LocalServer {' > jaas1.config
    echo '    gov.va.med.vistalink.security.VistaLoginModule requisite' >> jaas1.config
    echo '    gov.va.med.vistalink.security.ServerAddressKey="127.0.0.1"' >> jaas1.config
    echo '    gov.va.med.vistalink.security.ServerPortKey="8001";' >> jaas1.config
    echo '};' >> jaas1.config
    output=$(java -Djava.security.auth.login.config="./jaas1.config" -cp $CLASSPATH gov.va.med.vistalink.samples.VistaLinkRpcConsole -s LocalServer -a ${accessCode} -v ${verifyCode})
    echo "output: "$output
    cd ../..
    rm -rf vistalink-tester-for-linux-master
    [ $(expr "$output" : ".*Successful.*Gettysburg.*") -ne 0 ]
}
