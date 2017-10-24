inside {
  properties ([
    [ $class: 'BuildDiscarderProperty', strategy: [ $class: 'LogRotator', daysToKeepStr: '7', numToKeep: '10' ] ],
  ])

  currentBuild.result = 'SUCCESS'

  stage('Checkout Code') {
    sh "/bin/sleep 600"
  }

}
