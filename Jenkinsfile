@Library('shared-library@master') _

inside {
  properties ([
    [ $class: 'BuildDiscarderProperty', strategy: [ $class: 'LogRotator', daysToKeepStr: '7', numToKeep: '10' ] ],
  ])

  currentBuild.result = 'SUCCESS'

  stage('Code Checkout') {
    checkout scm
  }

  stage('Build') {
    println "Building"
  }

  stage('Tests: Unit') {
    println "Running Unit tests"
  }

  stage('Quality Assessment') {
    println "Running code quality"
  }

  stage('Package') {
    println "Packaging"
  }

}
