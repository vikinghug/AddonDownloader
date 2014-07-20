runCommand = require "run-command"

runCommand "gulp", ['watch-pre-tasks'], ->
  runCommand("gulp", ['watch'])
