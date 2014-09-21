commander = require("commander")
chalk = require("chalk")
fs = require("fs")
path = require("path")
_ = require("lodash")
cmds = require("../commands")
util = require("../util")

{fatalError, infoMsg, programDone, runCommand, callCommand} = util
colors = data = history = maxHistory = historyFile = undefined

#
# load history and configuation
#

saveHistory = () ->
  util.saveJsonFile(historyFile, data)

initHistoryObj = () ->
  return {
    max: 10
    slots: []
  }

loadHistory = () ->
  data = loadJsonFile(historyFile, initHistoryObj)
  history = data.slots
  maxHistory = data.max
  return if _.isArray(history)
  console.error chalk.yellow "slots is missing from history.json, resetting history"
  data = initHistoryObj()
  saveHistory()

util.emitter.on "config:loaded", (config, dataDir) ->
  historyFile = path.join(dataDir, "history.json")
  {colors} = config

#
# actual command actions
#

histMsg = (msg) ->
  infoMsg "history", msg

runHistoryCmd = (cmd) ->
  runCommand(cmd, loadHistory)

historyCommands =
  getHistory: (idx) ->
    idx = parseInt(idx)
    fatalError "argument <idx> should be a whole number" unless _.isNumber(idx) and not _.isNaN(idx) and idx >= 0 and idx < history.length
    _path = history[idx]
    fatalError "path #{_path} is not a string" unless _.isString(_path)
    console.log _path
    programDone()

  addHistory: (_path) ->
    _path = process.cwd() unless _.isString(_path)
    fatalError "path #{_path} does not exist" unless fs.existsSync _path
    history = (slot for slot in history when slot isnt _path)
    history.unshift _path
    history.pop() if history.length > maxHistory
    saveDataFile()
    programDone()

  clearHistory: () ->
    console.error chalk.yellow "clearing history"
    data.history = []
    saveDataFile()
    programDone()

  listHistory: () ->
    histMsg "listing slots", "history"
    console.error "------------------------------"
    for _path, idx in history
      console.error "#{chalk.yellow idx}\t#{chalk.grey _path}"
    programDone()

  pickHistory: () ->
    callCommand "listHistory"
    programDone() unless history.length > 0
    readline = require "readline"
    rl = readline.createInterface
      input: process.stdin
      output: process.stderr
      terminal: colors
    rl.on "line", (line) ->
      idx = line.trim()
      if idx >= 0 and idx < history.length and _.isString(history[idx])
        commands.getHistory(line.trim())
      else
        rl.prompt()
    rl.prompt()

cmds.extend historyCommands

#
# add commander commands
#

# commander
#   .command("init")
#   .action(runHistoryCmd("init"));

commander
  .command("add-hist")
  .action(runHistoryCmd("addHistory"));

commander
  .command("clear-hist")
  .action(runHistoryCmd("clearHistory"));

commander
  .command("pick-hist")
  .action(runHistoryCmd("pickHistory"));
