#!/bin/bash
# Copyright (c) 2021, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
#Function to output message to StdErr
function echo_stderr() {
    echo "$@" >&2
}

#Function to display usage message
function usage() {
    echo_stderr "./elkIntegrationForDynamicCluster.sh <oracleHome> <wlsAdminURL> <managedServerPrefix> <wlsUserName> <wlsPassword> <wlsAdminServerName> <elasticURI> <elasticUserName> <elasticPassword> <wlsDomainName> <wlsDomainPath> <logsToIntegrate> <index> <logIndex> <maxDynamicClusterSize>"
}

function validate_input() {
    if [ -z "$oracleHome" ]; then
        echo_stderr "oracleHome is required. "
        exit 1
    fi

    if [ -z "$wlsAdminURL" ]; then
        echo_stderr "wlsAdminURL is required. "
        exit 1
    fi

    if [ -z "$managedServerPrefix" ]; then
        echo_stderr "managedServerPrefix is required. "
        exit 1
    fi

    if [[ -z "$wlsUserName" || -z "$wlsPassword" ]]; then
        echo_stderr "wlsUserName or wlsPassword is required. "
        exit 1
    fi

    if [ -z "$wlsAdminServerName" ]; then
        echo_stderr "wlsAdminServerName is required. "
        exit 1
    fi

    if [ -z "$elasticURI" ]; then
        echo_stderr "elasticURI is required. "
        exit 1
    fi

    if [[ -z "$elasticUserName" || -z "$elasticPassword" ]]; then
        echo_stderr "elasticUserName or elasticPassword is required. "
        exit 1
    fi

    if [ -z "$wlsDomainName" ]; then
        echo_stderr "wlsDomainName is required. "
        exit 1
    fi

    if [ -z "$wlsDomainPath" ]; then
        echo_stderr "wlsDomainPath is required. "
        exit 1
    fi

    if [ -z "$index" ]; then
        echo_stderr "index is required. "
        exit 1
    fi

    if [ -z "$logsToIntegrate" ]; then
        echo_stderr "logsToIntegrate is required. "
        exit 1
    fi

    if [ -z "$logIndex" ]; then
        echo_stderr "logIndex is required. "
        exit 1
    fi

    if [ -z "$maxDynamicClusterSize" ]; then
        echo_stderr "maxDynamicClusterSize is required. "
        exit 1
    fi
}

# Set access log with format: date time time-taken bytes c-ip  s-ip c-dns s-dns  cs-method cs-uri sc-status sc-comment ctx-ecid
# Redirect stdout logging enabled: true
# Redirect stderr logging enabled: true
# Stack Traces to stdout: true
function create_wls_log_model() {
    cat <<EOF >${SCRIPT_PATH}/configure-wls-log.py
connect('$wlsUserName','$wlsPassword','t3://$wlsAdminURL')
shutdown('$clusterName', 'Cluster')
try:
    edit("$hostName")
    startEdit()
    cd('/Servers/${wlsAdminServerName}/WebServer/${wlsAdminServerName}/WebServerLog/${wlsAdminServerName}')
    cmo.setLogFileFormat('extended')
    cmo.setELFFields('date time time-taken bytes c-ip  s-ip c-dns s-dns  cs-method cs-uri sc-status sc-comment ctx-ecid ctx-rid') 

    cd('/Servers/${wlsAdminServerName}/Log/${wlsAdminServerName}')
    cmo.setRedirectStderrToServerLogEnabled(true)
    cmo.setRedirectStdoutToServerLogEnabled(true)
    cmo.setStdoutLogStack(true)

    cd('/ServerTemplates/${serverTemplate}/WebServer/${serverTemplate}/WebServerLog/${serverTemplate}')
    cmo.setLogFileFormat('extended')
    cmo.setELFFields('date time time-taken bytes c-ip  s-ip c-dns s-dns  cs-method cs-uri sc-status sc-comment ctx-ecid ctx-rid') 

    cd('/ServerTemplates/${serverTemplate}/Log/${serverTemplate}')
    cmo.setRedirectStderrToServerLogEnabled(true)
    cmo.setRedirectStdoutToServerLogEnabled(true)
    cmo.setStdoutLogStack(true)

    save()
    resolve()
    activate()
except:
    stopEdit('y')
    sys.exit(1)
destroyEditSession("$hostName",force = true)
try: 
    start('$clusterName', 'Cluster')
except:
    dumpStack()
disconnect()
EOF
}

# Remove existing Logstash
function remove_logstash() {
    sudo systemctl status logstash
    if [ $? -ne 0 ]; then
        sudo systemctl stop logstash
    fi

    sudo yum remove -y -v logstash
    if [ $? -ne 0 ]; then
        echo_stderr "Fail to remove existing Logstash."
        exit 1
    fi
}

# Install Logstash
function install_logstash() {
    sudo rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch

    cat <<EOF >/etc/yum.repos.d/logstash.repo
[logstash-7.x]
name=Elastic repository for 7.x packages
baseurl=https://artifacts.elastic.co/packages/7.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md
EOF
    sudo yum install -y -v logstash
    if [ ! -d "/usr/share/logstash" ]; then
        echo_stderr "Fail to install Logstash."
        exit 1
    fi
}

# Start Logstash service
function start_logstash() {
    sudo systemctl enable logstash
    sudo systemctl daemon-reload

    #Start logstash
    attempt=1
    while [[ $attempt -lt 4 ]]; do
        echo "Starting logstash service attempt $attempt"
        sudo systemctl start logstash
        attempt=$(expr $attempt + 1)
        sudo systemctl status logstash | grep running
        if [[ $? == 0 ]]; then
            echo "logstash service started successfully"
            break
        fi
        sleep 1m
    done
}

function watch_server_log() {
    cat <<EOF >>/etc/logstash/conf.d/weblogic-logs.conf
    file {
EOF

    if [ $index -eq 0 ]; then
        serverName=$wlsAdminServerName
        wlsLogPath="${wlsDomainPath}/servers/${serverName}/logs"
        cat <<EOF >>/etc/logstash/conf.d/weblogic-logs.conf
        path => "${wlsLogPath}/${serverName}.log"
EOF
    else
        cat <<EOF >>/etc/logstash/conf.d/weblogic-logs.conf
        path => [
EOF
        count=1
        while [ $count -le $maxDynamicClusterSize ]; do
            serverName=${managedServerPrefix}${count}
            wlsLogPath="${wlsDomainPath}/servers/${serverName}/logs"
            if [ $count == $maxDynamicClusterSize ]; then
                cat <<EOF >>/etc/logstash/conf.d/weblogic-logs.conf
            "${wlsLogPath}/${serverName}.log"
        ]
EOF
            else
                cat <<EOF >>/etc/logstash/conf.d/weblogic-logs.conf
            "${wlsLogPath}/${serverName}.log",
EOF
            fi
            count=$((count + 1))
        done
    fi

    cat <<EOF >>/etc/logstash/conf.d/weblogic-logs.conf
        codec => multiline {
            pattern => "^####"
            negate => true
            what => "previous"
        }
        start_position => beginning
    }
EOF
}

function watch_access_log() {
    cat <<EOF >>/etc/logstash/conf.d/weblogic-logs.conf
    file {
EOF
    if [ $index -eq 0 ]; then
        serverName=$wlsAdminServerName
        wlsLogPath="${wlsDomainPath}/servers/${serverName}/logs"
        cat <<EOF >>/etc/logstash/conf.d/weblogic-logs.conf
        path => "${wlsLogPath}/access.log"
EOF
    else
        cat <<EOF >>/etc/logstash/conf.d/weblogic-logs.conf
        path => [
EOF
        count=1
        while [ $count -le $maxDynamicClusterSize ]; do
            serverName=${managedServerPrefix}${count}
            wlsLogPath="${wlsDomainPath}/servers/${serverName}/logs"
            if [ $count == $maxDynamicClusterSize ]; then
                cat <<EOF >>/etc/logstash/conf.d/weblogic-logs.conf
            "${wlsLogPath}/access.log"
        ]
EOF
            else
                cat <<EOF >>/etc/logstash/conf.d/weblogic-logs.conf
            "${wlsLogPath}/access.log",
EOF
            fi
            count=$((count + 1))
        done
    fi

    cat <<EOF >>/etc/logstash/conf.d/weblogic-logs.conf
        start_position => beginning
    }
EOF
}

function watch_domain_log() {
    cat <<EOF >>/etc/logstash/conf.d/weblogic-logs.conf
    file {
EOF
    if [ $index -eq 0 ]; then
        serverName=$wlsAdminServerName
        wlsLogPath="${wlsDomainPath}/servers/${serverName}/logs"
        cat <<EOF >>/etc/logstash/conf.d/weblogic-logs.conf
        path => "${wlsLogPath}/${wlsDomainName}.log"
EOF
    else
        cat <<EOF >>/etc/logstash/conf.d/weblogic-logs.conf
        path => [
EOF
        count=1
        while [ $count -le $maxDynamicClusterSize ]; do
            serverName=${managedServerPrefix}${count}
            wlsLogPath="${wlsDomainPath}/servers/${serverName}/logs"
            if [ $count == $maxDynamicClusterSize ]; then
                cat <<EOF >>/etc/logstash/conf.d/weblogic-logs.conf
            "${wlsLogPath}/${serverTemplate}.log"
        ]
EOF
            else
                cat <<EOF >>/etc/logstash/conf.d/weblogic-logs.conf
            "${wlsLogPath}/${serverTemplate}.log",
EOF
            fi
            count=$((count + 1))
        done
    fi

    cat <<EOF >>/etc/logstash/conf.d/weblogic-logs.conf
        codec => multiline {
            pattern => "^####"
            negate => true
            what => "previous"
        }
        start_position => beginning
    }
EOF
}

function watch_std_log() {
    cat <<EOF >>/etc/logstash/conf.d/weblogic-logs.conf
    file {
EOF
    if [ $index -eq 0 ]; then
        serverName=$wlsAdminServerName
        wlsLogPath="${wlsDomainPath}/servers/${serverName}/logs"
        cat <<EOF >>/etc/logstash/conf.d/weblogic-logs.conf
        path => "${wlsLogPath}/${serverName}.out"
EOF
    else
        cat <<EOF >>/etc/logstash/conf.d/weblogic-logs.conf
        path => [
EOF
        count=1
        while [ $count -le $maxDynamicClusterSize ]; do
            serverName=${managedServerPrefix}${count}
            wlsLogPath="${wlsDomainPath}/servers/${serverName}/logs"
            if [ $count == $maxDynamicClusterSize ]; then
                cat <<EOF >>/etc/logstash/conf.d/weblogic-logs.conf
            "${wlsLogPath}/${serverName}.out"
        ]
EOF
            else
                cat <<EOF >>/etc/logstash/conf.d/weblogic-logs.conf
            "${wlsLogPath}/${serverName}.out",
EOF
            fi
            count=$((count + 1))
        done
    fi

    cat <<EOF >>/etc/logstash/conf.d/weblogic-logs.conf
        codec => multiline {
            pattern => "^<"
            negate => true
            what => "previous"
        }
        start_position => beginning
    }
EOF
}

function watch_ds_log() {
    cat <<EOF >>/etc/logstash/conf.d/weblogic-logs.conf
    file {
EOF
    if [ $index -eq 0 ]; then
        serverName=$wlsAdminServerName
        wlsLogPath="${wlsDomainPath}/servers/${serverName}/logs"
        cat <<EOF >>/etc/logstash/conf.d/weblogic-logs.conf
        path => "${wlsLogPath}/datasource.log"
EOF
    else
        cat <<EOF >>/etc/logstash/conf.d/weblogic-logs.conf
        path => [
EOF
        count=1
        while [ $count -le $maxDynamicClusterSize ]; do
            serverName=${managedServerPrefix}${count}
            wlsLogPath="${wlsDomainPath}/servers/${serverName}/logs"
            if [ $count == $maxDynamicClusterSize ]; then
                cat <<EOF >>/etc/logstash/conf.d/weblogic-logs.conf
            "${wlsLogPath}/datasource.log"
        ]
EOF
            else
                cat <<EOF >>/etc/logstash/conf.d/weblogic-logs.conf
            "${wlsLogPath}/datasource.log",
EOF
            fi
            count=$((count + 1))
        done
    fi

    cat <<EOF >>/etc/logstash/conf.d/weblogic-logs.conf
        codec => multiline {
            pattern => "^####"
            negate => true
            what => "previous"
        }
        start_position => beginning
    }
EOF
}

# Configure Logstash:
#  * grok patterns -> /etc/logstash/patterns/weblogic-logstash-patterns.txt
#  * conf files -> /etc/logstash/conf.d
#  * JAVA_HOME -> /etc/logstash/startup.options
#  * create logstash start up
# Examples for patterns:
#  * ACCESSDATE
#   * parse date of access
#   * 2020-09-01
#  * DBDATETIME
#   * parse data source datetime
#   * Tue Sep 01 05:05:41 UTC 2020
#  * DSIDORTIMESTAMP
#   * parse data source dynamic fields: id | timestamp, one of them exists.
#   * timestamp: Tue Sep 01 05:05:41 UTC 2020
#   * id: 64
#  * DSPARTITION
#   * parse partition info.
#   * [partition-name: DOMAIN] [partition-id: 0]
#   * [partition-id: 0] [partition-name: DOMAIN]
#  * DSWEBLOGICMESSAGE
#   * parse data source user id or error messsage.
#   * error: Java stack trace
#   * user id: <anonymous>
#  * WEBLOGICDIAGMESSAGE
#   * parse domain log message.
#   * e.g. Java stack trace
#   * e.g. Self-tuning thread pool contains 0 running threads, 2 idle threads, and 13 standby threads
#  * WEBLOGICDOMAINDATE
#   * parse domain|server log datetime.
#   * from wls 14: Sep 1, 2020, 5:41:51,040 AM Coordinated Universal Time
#   * from wls 12: Sep 1, 2020 5:41:51,040 AM Coordinated Universal Time
#  * WEBLOGICLOGPARTITION
#   * parse partition info in domain log.
#   * [severity-value: 64]
#   * [severity-value: 64] [rid: 0]
#   * [severity-value: 64] [partition-id: 0] [partition-name: DOMAIN ]
#   * [severity-value: 64] [rid: 0] [partition-id: 0] [partition-name: DOMAIN ]
#  * WEBLOGICSERVERLOGPARTITION
#   * parse partition info in server log.
#   * [severity-value: 64]
#   * [severity-value: 64] [rid: 0]
#   * [severity-value: 64] [partition-id: 0] [partition-name: DOMAIN ]
#   * [severity-value: 64] [rid: 0] [partition-id: 0] [partition-name: DOMAIN ]
#  * WEBLOGICSERVERRID
#   * parse dynamic filed rid in server log.
#   * [rid: 0]
#  * WEBLOGICSERVERMESSAGE
#   * parse field message in server log.
#   * e.g. Java stack trace
#   * e.g. Self-tuning thread pool contains 0 running threads, 2 idle threads, and 13 standby threads
#  * WEBLOGICSTDDATE
#   * parse field date in std log.
#   * Aug 31, 2020 5:37:27,646 AM UTC
#   * Aug 31, 2020 5:37:27 AM UTC
function configure_lostash() {
    echo "create patterns"
    rm -f -r /etc/logstash/patterns
    if [ -d "/etc/logstash/patterns" ]; then
        rm -f /etc/logstash/patterns/weblogic-logstash-patterns.txt
    else
        mkdir /etc/logstash/patterns
    fi
    cat <<EOF >/etc/logstash/patterns/weblogic-logstash-patterns.txt
ACCESSDATE ^\d{4}[./-]%{MONTHNUM}[./-]%{MONTHDAY}
DBDATETIME %{DAY} %{MONTH:db_month} %{MONTHDAY:db_day} %{HOUR:db_hour}:%{MINUTE:db_minute}:%{SECOND:db_second} %{TZ:db_tz} %{YEAR:db_year}
DSIDORTIMESTAMP (?<ds_Id>(\b(?:[1-9][0-9]*)\b))|%{DBDATETIME:ds_timestamp}
DSPARTITION (?:\[partition-id: %{INT:ds_partitionId}\] \[partition-name: %{DATA:ds_partitionName}\]\s)|(?:\[partition-name: %{DATA:ds_partitionName}\] \[partition-id: %{INT:ds_partitionId}\]\s)
DSWEBLOGICMESSAGE (?<ds_error>(.|\r|\n)*)|%{GREEDYDATA:ds_user}
JAVAPACKAGE ([a-zA-Z_$][a-zA-Z\d_$]*\.)*[a-zA-Z_$][a-zA-Z\d_$]*
NODEMANAGERMESSAGE (?<node_message>(.|\r|\n[^A-Za-z0-9])*)|%{GREEDYDATA:node_message}
NODEMANAGEREND (<%{WORDNOSPACES:node_domain}>\s<%{WORDNOSPACES:node_server}>\s<%{NODEMANAGERMESSAGE}>)|(<%{GREEDYDATA:node_messageType}>\s<%{NODEMANAGERMESSAGE}>)|<%{NODEMANAGERMESSAGE}>
WEBLOGICDIAGMESSAGE (?<diag_message>(.|\r|\n)*)|%{GREEDYDATA:diag_message}
WEBLOGICDOMAINDATE %{MONTH:tmp_month} %{MONTHDAY:tmp_day}, %{YEAR:tmp_year},? %{HOUR:tmp_hour}:%{MINUTE:tmp_min}:%{SECOND:tmp_second},(?<tmp_sss>([0-9]{3})) (?<tmp_aa>(AM|PM))
WEBLOGICLOGPARTITION (?:\s\[rid: %{DATA:diag_rid}\] \[partition-id: %{INT:diag_partitionId}\] \[partition-name: %{DATA:diag_partitionName}\]\s)|(?:\s\[partition-id: %{INT:diag_partitionId}\] \[partition-name: %{DATA:diag_partitionName}\]\s)|(?:\s\[rid: %{DATA:diag_rid}\]\s)|(\s)
WEBLOGICSERVERLOGPARTITION (?:\s\[rid: %{DATA:log_rid}\] \[partition-id: %{INT:log_partitionId}\] \[partition-name: %{DATA:log_partitionName}\]\s)|(?:\s\[partition-id: %{INT:log_partitionId}\] \[partition-name: %{DATA:log_partitionName}\]\s)|(?:\s\[rid: %{DATA:log_rid}\]\s)|(\s)
WEBLOGICSERVERRID (?:\s\[rid: %{WORDNOSPACES:log_rid}\]\s)|(\s)
WEBLOGICSERVERMESSAGE (?<log_message>(.|\r|\n)*)|%{GREEDYDATA:log_message}
WEBLOGICSTDDATE %{MONTH:tmp_month} %{MONTHDAY:tmp_day}, %{YEAR:tmp_year},? %{HOUR:tmp_hour}:%{MINUTE:tmp_min}:%{SECOND:tmp_second} (?<tmp_aa>(AM|PM))
WEBLOGICSTDMESSAGE (?<out_message>(.|\r|\n[^A-Za-z0-9])*)|%{GREEDYDATA:out_message}
WEBLOGICSTDDYNAMICID (<%{WORDNOSPACES:out_messageId}>\s<%{WEBLOGICSTDMESSAGE}>)|<%{WEBLOGICSTDMESSAGE}>
WORDNOSPACES [^ ]*
WORDNOBRACKET [^\]]*
WORDWITHSPACE (\b\w+\b|\s)*
EOF

    if [ $index -eq 0 ]; then
        serverName=$wlsAdminServerName
    else
        serverName=${managedServerPrefix}${index}
    fi
    wlsLogPath="${wlsDomainPath}/servers/${serverName}/logs"
    privateIP=$(ip addr | grep 'state UP' -A2 | tail -n1 | awk '{print $2}' | cut -f1 -d'/')

    rm -f /etc/logstash/conf.d/weblogic-logs.conf
    cat <<EOF >/etc/logstash/conf.d/weblogic-logs.conf
input {
EOF

    if [[ -n $(echo ${logsToIntegrate} | grep "HTTPAccessLog") ]]; then
        watch_access_log
    fi

    if [[ -n $(echo ${logsToIntegrate} | grep "ServerLog") ]]; then
        watch_server_log
    fi

    if [[ -n $(echo ${logsToIntegrate} | grep "DomainLog") ]]; then
        watch_domain_log
    fi

    if [[ -n $(echo ${logsToIntegrate} | grep "DataSourceLog") ]]; then
        watch_ds_log
    fi

    if [[ -n $(echo ${logsToIntegrate} | grep "StandardErrorAndOutput") ]]; then
        watch_std_log
    fi

    if [[ -n $(echo ${logsToIntegrate} | grep "NodeManagerLog") ]]; then
        cat <<EOF >>/etc/logstash/conf.d/weblogic-logs.conf
    file {
        path => "${wlsDomainPath}/nodemanager/nodemanager.log"
        codec => multiline {
            pattern => "^<"
            negate => true
            what => "previous"
        }
        start_position => beginning
    }
EOF
    fi

    cat <<EOF >>/etc/logstash/conf.d/weblogic-logs.conf
}
filter {
    grok {
        match => {"path" => "%{GREEDYDATA}/%{GREEDYDATA:type}"}
    }
    mutate {
        add_field => { "internal_ip" => "${privateIP}" }
    }

    if [type] == "${wlsAdminServerName}.log" or [type] =~ /^${managedServerPrefix}\d+.log/ {
        mutate { replace => { type => "weblogic_server_log" } }
        # match rid
        grok {
            patterns_dir=> ["/etc/logstash/patterns"]
            match => [ "message", "####<%{WEBLOGICDOMAINDATE}%{SPACE}%{GREEDYDATA:log_timezone}>%{SPACE}<%{LOGLEVEL:log_severity}>%{SPACE}<%{GREEDYDATA:log_subSystem}>%{SPACE}<%{HOSTNAME:log_machine}>%{SPACE}<%{DATA:log_server}>%{SPACE}<%{DATA:log_thread}>%{SPACE}<%{DATA:log_userId}>%{SPACE}<%{DATA:log_transactionId}>%{SPACE}<%{DATA:log_contextId}>%{SPACE}<%{NUMBER:log_timestamp}>%{SPACE}<\[severity-value: %{INT:log_severityValue}\]%{WEBLOGICSERVERLOGPARTITION}>%{SPACE}<%{DATA:log_massageId}>%{SPACE}<%{WEBLOGICSERVERMESSAGE}>" ]
        }

        mutate { 
            replace => ['log_date', '%{tmp_month} %{tmp_day}, %{tmp_year} %{tmp_hour}:%{tmp_min}:%{tmp_second},%{tmp_sss} %{tmp_aa}']
        }

        translate {
            field       => 'log_timezone'
            destination => 'log_timezone'
            fallback => '%{log_timezone}'
            override => "true"
            dictionary  => {
                "Coordinated Universal Time" => "UTC"
            }
        }

        date {
            match => [ "log_date", "MMM dd, YYYY KK:mm:ss,SSS aa", "MMM d, YYYY KK:mm:ss,SSS aa"]
            timezone => "%{log_timezone}"
            target => "log_date"
        }
        mutate {
            remove_field => [ 'log_timezone', 'tmp_month', 'tmp_day', 'tmp_year', 'tmp_hour', 'tmp_min', 'tmp_second', 'tmp_sss', 'tmp_aa']
        }
    }
    else if [type] == "access.log" {
        # drop message starting with #
        if [message] =~ /^#/ {
            drop {}
        }
        mutate { replace => { type => "weblogic_access_log" } }
        grok {
            patterns_dir=> ["/etc/logstash/patterns"]
            match => [ "message", "%{ACCESSDATE:acc_date}\s+%{TIME:acc_time}\s+%{NUMBER:time_taken}\s+%{NUMBER:bytes:int}\s+%{IP:c_ip}\s+%{HOSTPORT:s_ip}\s+%{IPORHOST:c_dns}\s+%{IPORHOST:s_dns}\s+%{WORD:cs_method}\s+%{URIPATHPARAM:cs_uri}\s+%{NUMBER:sc_status}\s+%{QUOTEDSTRING:sc-comment}\s+%{WORDNOSPACES:ctx-ecid}\s+%{WORDNOSPACES:ctx-rid}" ]
        }
        mutate { 
            replace => ['acc_timestamp', '%{acc_date} %{acc_time}']
        }
        date {
            match => [ "acc_timestamp" , "yyyy-MM-dd HH:mm:ss" ]
            timezone => "UTC"
            target => "acc_timestamp"
        }
        mutate {
            remove_field => [ 'acc_date', 'acc_time']
        }
    }
    else if [type] == "${wlsDomainName}.log" or [type] == "${serverTemplate}.log" {
        mutate { replace => { type => "weblogic_domain_log" } }
        grok {
            patterns_dir=> ["/etc/logstash/patterns"]
            match => [ "message", "####<%{WEBLOGICDOMAINDATE}%{SPACE}%{GREEDYDATA:diag_timezone}>%{SPACE}<%{LOGLEVEL:diag_severity}>%{SPACE}<%{GREEDYDATA:diag_subSystem}>%{SPACE}<%{HOSTNAME:diag_machine}>%{SPACE}<%{HOSTNAME:diag_server}>%{SPACE}<%{DATA:diag_thread}>%{SPACE}<%{WORDNOBRACKET:diag_userId}>%{SPACE}<%{DATA:diag_transactionId}>%{SPACE}<%{WORDNOSPACES:diag_contextId}>%{SPACE}<%{NUMBER:diag_timestamp}>%{SPACE}<\[severity-value: %{INT:diag_severityValue}\]%{WEBLOGICLOGPARTITION}>%{SPACE}<%{DATA:diag_massageId}>%{SPACE}<%{WEBLOGICDIAGMESSAGE}>" ]
        }

        mutate { 
            replace => ['diag_date', '%{tmp_month} %{tmp_day}, %{tmp_year} %{tmp_hour}:%{tmp_min}:%{tmp_second},%{tmp_sss} %{tmp_aa}']
        }

        translate {
            field       => 'diag_timezone'
            destination => 'diag_timezone'
            fallback => '%{diag_timezone}'
            override => "true"
            dictionary  => {
                "Coordinated Universal Time" => "UTC"
            }
        }

        date {
            match => [ "diag_date", "MMM dd, YYYY KK:mm:ss,SSS aa", "MMM d, YYYY KK:mm:ss,SSS aa"]
            timezone => "%{diag_timezone}"
            target => "diag_date"
        }
        mutate {
            remove_field => [ 'diag_timezone', 'tmp_month', 'tmp_day', 'tmp_year', 'tmp_hour', 'tmp_min', 'tmp_second', 'tmp_sss', 'tmp_aa']
        }
    }
    else if [type] == "datasource.log" {
        mutate { replace => { type => "weblogic_datasource_log" } }
        # with timestamp
        grok {
            patterns_dir=> ["/etc/logstash/patterns"]
            match => [ "message", "####<%{WORDNOSPACES:ds_dataSource}>%{SPACE}<%{WORDNOSPACES:ds_profileType}>%{SPACE}<%{DSIDORTIMESTAMP}>%{SPACE}<%{DSWEBLOGICMESSAGE}>%{SPACE}<%{DATA:ds_info}>%{SPACE}<%{DSPARTITION}>" ]
        }

        if ([db_month]) {
            # DBDATETIME %{DAY} %{MONTH:db_month} %{MONTHDAY:db_day} %{HOUR:db_hour}:%{MINUTE:db_minute}:%{SECOND:db_second} %{TZ:db_tz} %{YEAR:db_year}
            mutate { 
                replace => ["ds_timestamp", "%{db_month} %{db_day}, %{db_year} %{db_hour}:%{db_minute}:%{db_second}"]
            }

            date {
                match => [ "ds_timestamp", "MMM dd, YYYY HH:mm:ss", "MMM  d, YYYY HH:mm:ss"]
                timezone => "%{db_tz}"
                target => "ds_timestamp"
            }
            mutate {
                remove_field => [ 'db_month','db_day','db_year','db_hour','db_minute','db_second','db_tz']
            }
        }
    }
    else if [type] == "${wlsAdminServerName}.out" or [type] =~ /^${managedServerPrefix}\d+.out/ {
        mutate { replace => { type => "weblogic_std_log" } }
        grok {
            patterns_dir=> ["/etc/logstash/patterns"]
            match => [ "message", "<%{WEBLOGICSTDDATE}%{SPACE}%{WORDWITHSPACE:out_timezone}>%{SPACE}<%{WORDWITHSPACE:out_level}>%{SPACE}<%{WORDWITHSPACE:out_subsystem}>%{SPACE}%{WEBLOGICSTDDYNAMICID}"]
        }
        
         mutate { 
            replace => ['out_timestamp', '%{tmp_month} %{tmp_day}, %{tmp_year} %{tmp_hour}:%{tmp_min}:%{tmp_second} %{tmp_aa}']
        }

        # CEST id does not exist in JODA-TIME, changed to CET
        translate {
            field       => 'out_timezone'
            destination => 'out_timezone'
            fallback => '%{out_timezone}'
            override => "true"
            dictionary  => {
                "CEST" => "CET"
                "Coordinated Universal Time" => "UTC"
            }
        }
        
        date {
            match => [ "out_timestamp", "MMM dd, YYYY KK:mm:ss aa", "MMM d, YYYY KK:mm:ss aa", "MMM dd, YYYY KK:mm:ss,SSS aa", "MMM d, YYYY KK:mm:ss,SSS aa"]
            timezone => "%{out_timezone}"
            target => "out_timestamp"
        }
        mutate {
            remove_field => [ 'out_timezone','tmp_month', 'tmp_day', 'tmp_year', 'tmp_hour', 'tmp_min', 'tmp_second', 'tmp_aa']
        }
    }
    else if [type] == "nodemanager.log" {
        mutate { replace => { type => "weblogic_nodemanager_log" } }
        grok {
            patterns_dir=> ["/etc/logstash/patterns"]
            match => [ "message", "<%{WEBLOGICSTDDATE}%{SPACE}%{WORDWITHSPACE:node_timezone}>%{SPACE}<%{WORDWITHSPACE:node_level}>%{SPACE}%{NODEMANAGEREND}"]
        }
        
         mutate { 
            replace => ['node_timestamp', '%{tmp_month} %{tmp_day}, %{tmp_year} %{tmp_hour}:%{tmp_min}:%{tmp_second} %{tmp_aa}']
        }

        # CEST id does not exist in JODA-TIME, changed to CET
        translate {
            field       => 'node_timezone'
            destination => 'node_timezone'
            fallback => '%{node_timezone}'
            override => "true"
            dictionary  => {
                "CEST" => "CET"
                "Coordinated Universal Time" => "UTC"
            }
        }
        
        date {
            match => [ "node_timestamp", "MMM dd, YYYY KK:mm:ss aa", "MMM d, YYYY KK:mm:ss aa", "MMM dd, YYYY KK:mm:ss,SSS aa", "MMM d, YYYY KK:mm:ss,SSS aa"]
            timezone => "%{node_timezone}"
            target => "node_timestamp"
        }
        mutate {
            remove_field => [ 'node_timezone','tmp_month', 'tmp_day', 'tmp_year', 'tmp_hour', 'tmp_min', 'tmp_second', 'tmp_aa']
        }
    }
}
output {
  elasticsearch {
    hosts => "${elasticURI}"
    user => "${elasticUserName}"
    password => "${elasticPassword}"
    index => "${logIndex}"
  }
}
EOF

    # Add JAVA_HOME to startup.options
    cp /etc/logstash/startup.options /etc/logstash/startup.options.elksave
    sed -i -e "/JAVACMD/a\\JAVA_HOME=${JAVA_HOME}" /etc/logstash/startup.options
    sed -i -e "s:LS_USER=.*:LS_USER=${userOracle}:g" /etc/logstash/startup.options
    sed -i -e "s:LS_GROUP=.*:LS_GROUP=${groupOracle}:g" /etc/logstash/startup.options

    # For Java 11
    # ISSUE: https://github.com/elastic/logstash/issues/10496
    java_version=$(java -version 2>&1 | sed -n ';s/.* version "\(.*\)\.\(.*\)\..*"/\1\2/p;')
    if [ ${java_version:0:3} -ge 110 ]; then
        cp /etc/logstash/jvm.options /etc/logstash/jvm.options.elksave
        cat <<EOF >>/etc/logstash/jvm.options
--add-opens java.base/sun.nio.ch=org.jruby.dist 
--add-opens java.base/java.io=org.jruby.dist
EOF
    fi

    # create start up for logstash
    /usr/share/logstash/bin/system-install /etc/logstash/startup.options
    if [ $? -ne 0 ]; then
        echo_stderr "Failed to set up logstash service."
        exit 1
    fi

    sudo chown -R ${userOracle}:${groupOracle} /var/lib/logstash
    sudo chown -R ${userOracle}:${groupOracle} /etc/logstash
}

function configure_wls_log() {
    echo "Configure WebLogic Log"
    sudo chown -R ${userOracle}:${groupOracle} ${SCRIPT_PATH}
    runuser -l oracle -c ". $oracleHome/oracle_common/common/bin/setWlstEnv.sh; java $WLST_ARGS weblogic.WLST ${SCRIPT_PATH}/configure-wls-log.py"

    errorCode=$?
    if [ $errorCode -eq 1 ]; then
        echo "Exception occurs during ELK configuration, please check."
        exit 1
    fi
}

function setup_javahome() {
    . $oracleHome/oracle_common/common/bin/setWlstEnv.sh
}

function restart_admin_service() {
    echo "Restart weblogic admin server"
    echo "Stop admin server"
    shutdown_admin
    sudo systemctl start wls_admin
    echo "Waiting for admin server to be available"
    wait_for_admin
    echo "Weblogic admin server is up and running"
}

function restart_cluster() {
    cat <<EOF >${SCRIPT_PATH}/restart-cluster.py
# Connect to the AdminServer.
connect('$wlsUserName','$wlsPassword','t3://$wlsAdminURL')
print "Restart cluster."
try: 
    print "Shutdown cluster."
    shutdown('$clusterName', 'Cluster')
    print "Start cluster."
    start('$clusterName', 'Cluster')
except:
    dumpStack()

disconnect()
EOF

    sudo chown -R ${userOracle}:${groupOracle} ${SCRIPT_PATH}
    runuser -l oracle -c ". $oracleHome/oracle_common/common/bin/setWlstEnv.sh; java $WLST_ARGS weblogic.WLST ${SCRIPT_PATH}/restart-cluster.py"
    errorCode=$?
    if [ $errorCode -eq 1 ]; then
        echo "Failed to restart cluster."
        exit 1
    fi
}

#This function to check admin server status
function wait_for_admin() {
    #check admin server status
    count=1
    CHECK_URL="http://$wlsAdminURL/weblogic/ready"
    status=$(curl --insecure -ILs $CHECK_URL | tac | grep -m1 HTTP/1.1 | awk {'print $2'})
    echo "Check admin server status"
    while [[ "$status" != "200" ]]; do
        echo "."
        count=$((count + 1))
        if [ $count -le 30 ]; then
            sleep 1m
        else
            echo "Error : Maximum attempts exceeded while checking admin server status"
            exit 1
        fi
        status=$(curl --insecure -ILs $CHECK_URL | tac | grep -m1 HTTP/1.1 | awk {'print $2'})
        if [ "$status" == "200" ]; then
            echo "WebLogic Server is running..."
            break
        fi
    done
}

# shutdown admin server
function shutdown_admin() {
    #check admin server status
    count=1
    CHECK_URL="http://$wlsAdminURL/weblogic/ready"
    status=$(curl --insecure -ILs $CHECK_URL | tac | grep -m1 HTTP/1.1 | awk {'print $2'})
    echo "Check admin server status"
    while [[ "$status" == "200" ]]; do
        echo "."
        count=$((count + 1))
        sudo systemctl stop wls_admin
        if [ $count -le 30 ]; then
            sleep 1m
        else
            echo "Error : Maximum attempts exceeded while stopping admin server"
            exit 1
        fi
        status=$(curl --insecure -ILs $CHECK_URL | tac | grep -m1 HTTP/1.1 | awk {'print $2'})
        if [ -z ${status} ]; then
            echo "WebLogic Server is stop..."
            break
        fi
    done
}

function cleanup() {
    echo "Cleaning up temporary files..."
    rm -f -r ${SCRIPT_PATH}
    echo "Cleanup completed."
}

function create_temp_folder()
{
    SCRIPT_PATH="/u01/tmp"
    sudo rm -f -r ${SCRIPT_PATH}
    sudo mkdir ${SCRIPT_PATH}
    sudo rm -rf $SCRIPT_PATH/*
}

function validate_elastic_server()
{
    timestamp=$(date +%s)
    testIndex="${logIndex}-validate-elk-server-from-server-${index}-${timestamp}"
    output=$(curl -XPUT --user ${elasticUserName}:${elasticPassword}  ${elasticURI}/${testIndex})
    if [[ $? -eq 1 ||  -z `echo $output | grep "\"acknowledged\":true"` ]];then
        echo $output
        exit 1
    fi

    count=1
    status404="\"status\":404"
    while [[ -n ${status404} ]]; do
        echo "."
        count=$((count + 1))
        # remove the test index
        echo "Removing test index..."
        curl -XDELETE --user ${elasticUserName}:${elasticPassword}  ${elasticURI}/${testIndex}
        echo "Checking if test index is removed."
        status404=$(curl -XGET --user ${elasticUserName}:${elasticPassword}  ${elasticURI}/${testIndex} | grep "\"status\":404")
        echo ${status404}
        if [[ -n ${status404} ]]; then
            echo "Test index is removed..."
            break
        fi

        if [ $count -le 30 ]; then
            sleep 1m
        else
            echo "Error : Maximum attempts exceeded while removing test index from elastic server"
            exit 1
        fi
    done
}

#main script starts here

SCRIPT_PWD=$(pwd)

if [ $# -ne 15 ]; then
    usage
    exit 1
fi

oracleHome=$1
wlsAdminURL=$2
managedServerPrefix=$3
wlsUserName=$4
wlsPassword=$5
wlsAdminServerName=$6
elasticURI=$7
elasticUserName=$8
elasticPassword=$9
wlsDomainName=${10}
wlsDomainPath=${11}
logsToIntegrate=${12}
index=${13}
logIndex=${14}
maxDynamicClusterSize=${15}

hostName=$(hostname)
userOracle="oracle"
groupOracle="oracle"
clusterName="cluster1"
serverTemplate="myServerTemplate"

create_temp_folder
validate_input
validate_elastic_server

echo "start to configure ELK"
setup_javahome

if [ $index -eq 0 ]; then
    create_wls_log_model
    configure_wls_log
    restart_admin_service
    echo "Waiting for admin server to be available"
    wait_for_admin
    echo "Weblogic admin server is up and running"
    restart_cluster
fi

remove_logstash
install_logstash
configure_lostash
start_logstash
cleanup
