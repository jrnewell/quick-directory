commander = require("commander")
chalk = require("chalk")
fs = require("fs")
path = require("path")
_ = require("lodash")
cmds = require("../commands")
util = require("../util")

{fatalError, infoMsg, programDone, runCommand, callCommand} = util
colors = data = schemes = schemesFile = scheme = currentScheme = autoCompact = undefined

#
# load schemes and configuation
#

saveSchemes = () ->
  util.saveJsonFile(schemesFile, data)

initSchemesObj = () ->
  return {
    currentScheme: "default"
    autoCompact: true
    schemes: {
      default:
        next: 0
        slots: {}
    }
  }

initalizeScheme = (scheme) ->
  schemes[scheme] =
    next: 0
    slots: {}
  saveSchemes()

loadSchemes = () ->
  data = util.loadJsonFile(schemesFile, initSchemesObj)
  {currentScheme, autoCompact, schemes} = data
  scheme = schemes[currentScheme]
  return if _.isObject(scheme)
  console.error chalk.yellow "currentScheme is missing from schemes.json, setting to 'default' scheme"
  initalizeScheme "default" unless _.isObject(schemes["default"])
  currentScheme = "default"
  scheme = schemes[currentScheme]

util.emitter.on "config:loaded", (config, dataDir) ->
  schemesFile = path.join(dataDir, "schemes.json")
  {colors} = config

#
# actual command actions
#

schemeMsg = (msg) ->
  infoMsg currentScheme, msg

doAutoCompact = () ->
  schemeMsg "auto compacting is enabled"
  callCommand "compactSlots"

getPathDuplicate = (_path) ->
  for idx, schemePath of scheme.slots
    return idx if path.resolve(schemePath) is path.resolve(_path)
  return null

runSchemesCommand = (cmd) ->
  runCommand(cmd, loadSchemes)

schemeCommands =
  printCurrentScheme: () ->
    console.error currentScheme
    programDone()

  changeScheme: (name) ->
    schemeCommands.printCurrentScheme() unless name?
    programDone() if name is currentScheme

    data.currentScheme = currentScheme = name
    console.error "changing scheme to #{chalk.cyan name}"
    if _.isObject(data.schemes[name])
      saveSchemes()
    else
      console.error chalk.grey "initializing empty scheme object"
      initalizeScheme name
    programDone()

  listSchemes: () ->
    console.error "schemes"
    console.error "------------------------------"
    for scheme in _.keys(data.schemes)
      console.error chalk.gray scheme

  dropScheme: (_scheme) ->
    _scheme ?= currentScheme
    console.error "Droping scheme #{chalk.cyan _scheme}"
    delete schemes[_scheme]
    data.currentScheme = currentScheme = "default" if _scheme is currentScheme
    saveSchemes()
    programDone()

  renameScheme: (name) ->
    return if name is currentScheme
    schemeMsg "renaming scheme #{currentScheme} to '#{name}'"
    schemes[name] = scheme
    delete schemes[currentScheme]
    data.currentScheme = currentScheme = name
    saveSchemes()
    programDone()

  listSlots: () ->
    schemeMsg "listing slots"
    console.error "------------------------------"
    slots = _.sortBy(_.pairs(scheme.slots), (pair) -> parseInt(pair[0]))
    for pair in slots
      console.error "#{chalk.yellow pair[0]}\t#{chalk.grey pair[1]}"
    programDone()

  pickSlot: () ->
    callCommand "listSlots"
    programDone() unless _.keys(scheme.slots).length > 0
    readline = require "readline"
    rl = readline.createInterface
      input: process.stdin
      output: process.stderr
      terminal: colors
    rl.on "line", (line) ->
      idx = line.trim()
      if _.isString(scheme.slots[idx])
        schemeCommands.getSlot(line.trim())
      else
        rl.prompt()
    rl.prompt()

  getSlot: (idx, _commander) ->
    unless idx.match /^[0-9]+$/
      fatalError "#{currentScheme} scheme is empty" if _.isEmpty(scheme.slots)
      args = _commander.parent.rawArgs[3..]
      console.log util.fuzzySearch args, scheme.slots
      programDone()
    else
      idx = parseInt(idx)
      fatalError "argument <idx> should be a whole number" unless _.isNumber(idx) and not _.isNaN(idx) and idx >= 0
      _path = scheme.slots[idx]
      fatalError "path #{_path} is not a string" unless _.isString(_path)
      console.log _path
      programDone()

  removeSlot: (idx) ->
    idx = parseInt(idx)
    fatalError "argument <idx> should be a whole number" unless _.isNumber(idx) and not _.isNaN(idx) and idx >= 0
    delete scheme.slots[idx]
    doAutoCompact() if autoCompact
    saveSchemes()
    programDone()

  switchSlots: (idx1, idx2) ->
    idx1 = parseInt(idx1)
    fatalError "argument <idx1> should be a whole number" unless _.isNumber(idx1) and not _.isNaN(idx1) and idx1 >= 0
    idx2 = parseInt(idx2)
    fatalError "argument <idx2> should be a whole number" unless _.isNumber(idx2) and not _.isNaN(idx2) and idx2 >= 0
    fatalError "argument <idx1> is not valid" unless _.isString(scheme.slots[idx1])
    fatalError "argument <idx2> is not valid" unless _.isString(scheme.slots[idx2])
    temp = scheme.slots[idx1]
    scheme.slots[idx1] = scheme.slots[idx2]
    scheme.slots[idx2] = temp
    saveSchemes()
    programDone()

  saveSlot: (idx, _path) ->
    if idx? and idx.match /^[0-9]+$/
      idx = parseInt(idx)
      fatalError "argument <idx> should be a whole number" unless _.isNumber(idx) and not _.isNaN(idx) and idx >= 0
    else
      # if idx is a string but not digits, assume it is the path
      _path = idx if _.isString(idx)
      idx = scheme.next

    _path = process.cwd() unless _.isString(_path)
    fatalError "path #{_path} does not exist" unless fs.existsSync _path
    dup = getPathDuplicate _path
    fatalError "path #{_path} already exists in slot #{dup}" if dup
    scheme.slots[idx] = _path
    doAutoCompact() if autoCompact and idx > scheme.next
    scheme.next = parseInt(_.max(_.keys(scheme.slots))) + 1
    schemeMsg "#{chalk.green 'saving'} slot #{chalk.yellow idx} as #{chalk.grey _path}"
    saveSchemes()
    programDone()

  # TODO: check for dups
  saveSlotsRecurse: (_path) ->
    _path = process.cwd() unless _.isString(_path)
    fatalError "path #{_path} does not exist" unless fs.existsSync _path
    # TODO: check for too many sub directories
    paths = [_path]
    fs.readdirSync(_path).forEach (dir) ->
      fullPath = path.join(_path, dir)
      stats = fs.statSync(fullPath)
      paths.push(fullPath) if stats.isDirectory()
    next = scheme.next
    for dir in paths
      dup = getPathDuplicate dir
      if dup
        schemeMsg "skipping #{chalk.grey dir}, already in slot #{chalk.yellow dup}"
      else
        schemeMsg "#{chalk.green 'saving'} slot #{chalk.yellow next} as #{chalk.grey dir}"
        scheme.slots[next] = dir
        next += 1
    doAutoCompact() if autoCompact
    scheme.next = parseInt(_.max(_.keys(scheme.slots))) + 1
    schemeMsg chalk.green "saved #{paths.length} directories"
    saveSchemes()
    programDone()

  clearSlots: () ->
    schemeMsg chalk.yellow "clearing all slots"
    scheme.slots = {}
    scheme.next = 0
    saveSchemes()
    programDone()

  compactSlots: () ->
    schemeMsg "compacting slot idx numbers"
    slotsArray = []
    for idx, slot of scheme.slots
      slotsArray.push
        idx: parseInt(idx)
        slot: slot
    slotsArray = _.sortBy(slotsArray, "idx")
    scheme.slots = {}
    for obj, idx in slotsArray
      scheme.slots[idx] = obj.slot
    scheme.next = parseInt(_.max(_.keys(scheme.slots))) + 1
    saveSchemes()
    programDone()

cmds.extend schemeCommands

#
# load scheme commands into commander
#
module.exports.load = () ->
  commander
    .command("scheme [name]")
    .description("changes schemes (prints current scheme if no name is given)")
    .action(runSchemesCommand("changeScheme"))

  commander
    .command("schemes")
    .action(runSchemesCommand("listSchemes"))

  commander
    .command("drop [name]")
    .action(runSchemesCommand("dropScheme"))

  commander
    .command("rename")
    .action(runSchemesCommand("renameScheme"))

  commander
    .command("list")
    .action(runSchemesCommand("listSlots"))

  commander
    .command("pick")
    .action(runSchemesCommand("pickSlot"))

  commander
    .command("get <idx>")
    .action(runSchemesCommand("getSlot"))

  commander
    .command("rm [idx]")
    .action(runSchemesCommand("removeSlot"))

  commander
    .command("switch <idx1> <idx2>")
    .action(runSchemesCommand("switchSlots"))

  commander
    .command("set [idx] [path]")
    .action(runSchemesCommand("saveSlot"))

  commander
    .command("setr [path]")
    .action(runSchemesCommand("saveSlotsRecurse"))

  commander
    .command("clear")
    .action(runSchemesCommand("clearSlots"))

  commander
    .command("compact")
    .action(runSchemesCommand("compactSlots"))
