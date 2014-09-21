chalk = require("chalk")
mkdirp = require("mkdirp")
fs = require("fs")
EventEmitter = require('events').EventEmitter
cmds = require("./commands")
config = require("./config")

{commands} = cmds
{loadConfig} = config
emitter = new EventEmitter()
disableExit = false

fatalError = (msg) ->
  console.error chalk.red(msg) if msg?
  process.exit(1)

programDone = () ->
  process.exit 0 unless disableExit

infoMsg = (header, msg) ->
  console.error chalk.cyan("[ #{header} ]") + " - #{msg}"

saveJsonFile = (fileName, obj) ->
  fs.writeFileSync(fileName, JSON.stringify(obj), "utf8")

loadJsonFile = (fileName, getInitObj) ->
  return JSON.parse(fs.readFileSync(fileName, "utf8")) if fs.existsSync fileName
  obj = getInitObj()
  saveJsonFile fileName, obj
  return obj

ensureDirExists = (path) ->
  mkdirp.sync(path) unless fs.existsSync(path)

runCommand = (cmd, initFunc) ->
  return () ->
    loadConfig()
    initFunc() if _.isFunction(initFunc)
    commands[cmd].apply(this, arguments)

callCommand = (cmd) ->
  disableExit = true
  args = Array.prototype.slice.call(arguments);
  args.shift()
  commands[cmd].apply(this, args)
  disableExit = false

module.exports = {
  emitter: emitter
  fatalError: fatalError
  programDone: programDone
  infoMsg: infoMsg
  saveJsonFile: saveJsonFile
  loadJsonFile: loadJsonFile
  ensureDirExists: ensureDirExists
  runCommand: runCommand
  callCommand: callCommand
}