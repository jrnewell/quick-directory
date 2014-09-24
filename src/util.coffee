chalk = require("chalk")
mkdirp = require("mkdirp")
fs = require("fs")
path = require("path")
EventEmitter = require('events').EventEmitter
_ = require("lodash")
cmds = require("./commands")

{commands} = cmds
loadConfig = undefined
emitter = new EventEmitter()
disableExit = false

# to prevent circular require dependencies
emitter.on "config:initialized", () ->
  loadConfig = require("./config").loadConfig

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

requireFiles = (dirPath, regex) ->
  fullPath = path.resolve(dirPath)
  if fs.existsSync(fullPath)
    fs.readdirSync(fullPath).forEach (file) ->
      return unless regex? and file.match(regex)
      filename = path.join(fullPath, file)
      stats = fs.statSync(filename)
      require(filename) if stats.isFile()

fuzzySearch = (str, slots) ->
  slots = _.values(slots) if _.isObject(slots)
  return unless _.isArray(slots)
  tokens = (if _.isString(str) then str.split /\W+/ else str)
  scores = []
  for slot in slots
    slotResults = []
    for token, tokenNum in tokens
      x = slot.indexOf token
      if x >= 0
        slotResults.push
          tokenNum: tokenNum
          x: x

    # sort by index
    slotResults = _.sortBy(slotResults, "x")

    #console.error slot
    #console.dir slotResults

    # calulate score
    score = 0
    prev = -1
    for result in slotResults
      point =
        if result.tokenNum == prev + 1
          3
        else if result.tokenNum > prev
          2
        else
          1

      #console.dir result
      #console.log "point: #{point}, prev: #{prev}"

      score += point + (result.x / 100)
      prev = result.tokenNum

    scores.push
      slot: slot
      score: score

  #console.dir scores

  return _.max(scores, "score").slot

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
  requireFiles: requireFiles
  fuzzySearch: fuzzySearch
}