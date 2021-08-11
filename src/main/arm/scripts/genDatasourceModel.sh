# Copyright (c) 2019, 2020, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

# Initialize
export script="${BASH_SOURCE[0]}"
export scriptDir="$(cd "$(dirname "${script}")" && pwd)"

export filePath=$1
export jndiName=$2
export target=$3
export driver=$4
export testTableName=$5
export secretName=$6

cat <<EOF >${filePath}
# Copyright (c) 2020, 2021, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

resources:
  JDBCSystemResource:
    ${jndiName}:
      Target: '${target}'
      JdbcResource:
        JDBCDataSourceParams:
          JNDIName: [
            ${jndiName}
          ]
          GlobalTransactionsProtocol: TwoPhaseCommit
        JDBCDriverParams:
          DriverName: ${driver}
          URL: '@@SECRET:${secretName}:url@@'
          PasswordEncrypted: '@@SECRET:${secretName}:password@@'
          Properties:
            user:
              Value: '@@SECRET:${secretName}:user@@'
        JDBCConnectionPoolParams:
            TestTableName: ${testTableName}
            TestConnectionsOnReserve: true
EOF
