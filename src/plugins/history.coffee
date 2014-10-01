commander = require("commander")
chalk = require("chalk")
fs = require("fs")
path = require("path")
_ = require("lodash")
cmds = require("../commands")
util = require("../util")

{vLog, fatalError, infoMsg, programDone, runCommand, callCommand} = util
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
  data = util.loadJsonFile(historyFile, initHistoryObj)
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
    histMsg "#{chalk.green 'changing'} working directory to #{chalk.grey _path}"
    console.log _path
    programDone()

  addHistory: (_path) ->
    _path = process.cwd() unless _.isString(_path)
    fatalError "path #{_path} does not exist" unless fs.existsSync _path
    data.slots = history = (slot for slot in history when slot isnt _path)
    history.unshift _path
    history.pop() if history.length > maxHistory
    saveHistory()
    programDone()

  clearHistory: () ->
    vLog chalk.yellow "clearing history"
    data.slots = history = []
    saveHistory()
    programDone()

  listHistory: () ->
    return histMsg "no slots in history" unless history.length > 0
    histMsg "listing slots", "history"
    vLog "------------------------------"
    for _path, idx in history
      console.error "#{chalk.yellow idx}\t#{chalk.grey _path}"
    programDone()

  getHistory: (idx, _commander) ->
    unless idx.match /^[0-9]+$/
      fatalError "history is empty" if _.isEmpty(history)
      args = _commander.parent.rawArgs[3..]
      _path = util.fuzzySearch args, history
      histMsg "#{chalk.green 'changing'} working directory to #{chalk.grey _path}"
      console.log _path
      programDone()
    else
      idx = parseInt(idx)
      fatalError "argument <idx> should be a whole number" unless _.isNumber(idx) and not _.isNaN(idx) and idx >= 0
      fatalError "arugment <idx> should be less than #{history.length}" unless idx < history.length
      _path = history[idx]
      fatalError "path #{_path} is not a string" unless _.isString(_path)
      histMsg "#{chalk.green 'changing'} working directory to #{chalk.grey _path}"
      console.log _path
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
        historyCommands.getHistory(line.trim())
      else
        rl.prompt()
    rl.prompt()

cmds.extend historyCommands

# listen for _cd events
util.emitter.on "cd:path", (_path) ->
  loadHistory()
  historyCommands.addHistory(_path)

#
# load history commands into commander
#
module.exports.load = () ->
  commander
    .command("add")
    .description("add entry to history (should be automatically called on cd)")
    .action(runHistoryCmd("addHistory"))

  commander
    .command("clear")
    .description("clear history")
    .action(runHistoryCmd("clearHistory"))

  commander
    .command("list")
    .description("list history")
    .action(runHistoryCmd("listHistory"))

  commander
    .command("get <idx>")
    .alias("go")
    .description("change to a history item <idx> (you can also give text for a fuzzy search)")
    .action(runHistoryCmd("getHistory"))

  commander
    .command("pick")
    .description("brings up a menu to choose a history item interactively")
    .action(runHistoryCmd("pickHistory"))
