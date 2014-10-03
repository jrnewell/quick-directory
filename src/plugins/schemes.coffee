commander = require("commander")
chalk = require("chalk")
fs = require("fs")
path = require("path")
os = require("os")
_ = require("lodash")
cmds = require("../commands")
util = require("../util")

{vLog, fatalError, infoMsg, programDone, ensureDirExists, runCommand, callCommand, confirmPrompt} = util
colors = schemeDir = schemes = dataFile = data = schemeFile = caseInsensitive =
  scheme = currentScheme = autoCompact = recurseWarn = undefined

#
# load schemes and configuation
#

saveSchemeConfig = () ->
  util.saveJsonFile(dataFile, data)

saveCurrentScheme = () ->
  util.saveJsonFile(schemeFile, scheme)

initConfigObj = () ->
  return {
    currentScheme: "default"
    autoCompact: true
    recurseWarn: 10
    schemes: ["default"]
  }

initSchemeObj = () ->
  return {
    next: 0
    slots: {}
  }

loadSchemes = () ->
  ensureDirExists schemeDir
  data = util.loadJsonFile(dataFile, initConfigObj)

  # defaults
  data.currentScheme ?= "default"
  data.autoCompact ?= true
  data.recurseWarn ?= 10
  data.schemes ?= ["default"]

  {currentScheme, autoCompact, recurseWarn, schemes} = data
  unless _.contains schemes, currentScheme
    schemes.push currentScheme
    saveSchemeConfig()

  schemeFile = path.join(schemeDir, "#{currentScheme}.json")
  scheme = util.loadJsonFile(schemeFile, initSchemeObj)
  return if _.isObject(scheme.slots)
  console.error chalk.yellow "slots is missing from #{currentScheme}.json, resetting slots"
  scheme = initSchemeObj()
  saveCurrentScheme()

util.emitter.on "config:loaded", (config, dataDir) ->
  caseInsensitive = os.platform() is "darwin" or os.platform().match /^win/
  schemeDir = path.join(dataDir, "schemes")
  dataFile = path.join(dataDir, "schemes.json")
  {colors} = config

#
# actual command actions
#

schemeMsg = (msg) ->
  infoMsg currentScheme, msg

doAutoCompact = () ->
  schemeMsg "auto compacting is enabled"
  callCommand "compactSlots"

# ignore case sensitivty
getPathDuplicate = (_path) ->
  for idx, schemePath of scheme.slots
    if caseInsensitive
      return idx if path.resolve(schemePath).toLowerCase() is path.resolve(_path).toLowerCase()
    else
      return idx if path.resolve(schemePath) is path.resolve(_path)
  return null

runSchemesCommand = (cmd) ->
  runCommand(cmd, loadSchemes)

schemeCommands =
  printCurrentScheme: () ->
    vLog "the current scheme is #{chalk.cyan currentScheme}"
    programDone()

  changeScheme: (name) ->
    schemeCommands.printCurrentScheme() unless name?
    programDone() if name is currentScheme

    data.currentScheme = currentScheme = name
    vLog "changing scheme to #{chalk.cyan name}"
    saveSchemeConfig()
    programDone()

  listSchemes: () ->
    vLog "listing schemes"
    vLog "------------------------------"
    for scheme in schemes
      console.error chalk.gray scheme

  dropScheme: (_scheme) ->
    _scheme ?= currentScheme
    vLog "Droping scheme #{chalk.cyan _scheme}"
    data.schemes = schemes = _.without(schemes, currentScheme)
    data.currentScheme = currentScheme = "default" if _scheme is currentScheme
    saveSchemeConfig()
    fs.unlinkSync(schemeFile) if fs.existsSync(schemeFile)
    programDone()

  renameScheme: (name) ->
    return if name is currentScheme
    schemeMsg "renaming scheme #{currentScheme} to '#{name}'"
    data.schemes = schemes = _.without(schemes, currentScheme)
    schemes.push name
    data.currentScheme = currentScheme = name
    saveSchemeConfig()

    oldSchemeFile = schemeFile
    schemeFile = path.join(schemeDir, "#{currentScheme}.json")
    fs.renameSync(oldSchemeFile, schemeFile) if fs.existsSync(oldSchemeFile)
    programDone()

  listSlots: () ->
    return schemeMsg "no slots in scheme" if _.isEmpty(scheme.slots)
    schemeMsg "listing slots"
    vLog "------------------------------"
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
      _path = util.fuzzySearch args, scheme.slots, _commander.ignoreCase
      schemeMsg "#{chalk.green 'changing'} working directory to #{chalk.grey _path}"
      console.log _path
      programDone()
    else
      idx = parseInt(idx)
      fatalError "argument <idx> should be a whole number" unless _.isNumber(idx) and not _.isNaN(idx) and idx >= 0
      _path = scheme.slots[idx]
      fatalError "path #{_path} is not a string" unless _.isString(_path)
      schemeMsg "#{chalk.green 'changing'} working directory to #{chalk.grey _path}"
      console.log _path
      programDone()

  removeSlot: (idx) ->
    idx = parseInt(idx)
    fatalError "argument <idx> should be a whole number" unless _.isNumber(idx) and not _.isNaN(idx) and idx >= 0
    schemeMsg "#{chalk.red 'removing'} path #{scheme.slots[idx]} in slot #{chalk.yellow idx}"
    delete scheme.slots[idx]
    doAutoCompact() if autoCompact
    saveCurrentScheme()
    programDone()

  swapSlots: (idx1, idx2) ->
    idx1 = parseInt(idx1)
    fatalError "argument <idx1> should be a whole number" unless _.isNumber(idx1) and not _.isNaN(idx1) and idx1 >= 0
    idx2 = parseInt(idx2)
    fatalError "argument <idx2> should be a whole number" unless _.isNumber(idx2) and not _.isNaN(idx2) and idx2 >= 0
    fatalError "argument <idx1> is not valid" unless _.isString(scheme.slots[idx1])
    fatalError "argument <idx2> is not valid" unless _.isString(scheme.slots[idx2])
    schemeMsg "#{chalk.green 'swapping'} slots #{chalk.yellow idx1} and #{chalk.yellow idx2}"
    temp = scheme.slots[idx1]
    scheme.slots[idx1] = scheme.slots[idx2]
    scheme.slots[idx2] = temp
    saveCurrentScheme()
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
    saveCurrentScheme()
    programDone()

  saveSlotsRecurse: (_path, _commander) ->
    _path = process.cwd() unless _.isString(_path)
    fatalError "path #{_path} does not exist" unless fs.existsSync _path
    paths = [_path]
    addSubDirs = (_path) ->
      fs.readdirSync(_path).forEach (dir) ->
        fullPath = path.join(_path, dir)
        stats = fs.statSync(fullPath)
        if stats.isDirectory()
          paths.push(fullPath)
          addSubDirs fullPath if _commander.children
    addSubDirs _path

    saveSlots = () ->
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
      saveCurrentScheme()
      programDone()

    if (paths.length > recurseWarn)
      confirmPrompt "This will save #{paths.length} slots into the current scheme, are you sure?", (err, confirm) ->
        return fatalError if err
        saveSlots() if confirm
    else
      saveSlots()

  clearSlots: () ->
    schemeMsg chalk.yellow "clearing all slots"
    scheme.slots = {}
    scheme.next = 0
    saveCurrentScheme()
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
    saveCurrentScheme()
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
    .description("lists all available schemes")
    .action(runSchemesCommand("listSchemes"))

  commander
    .command("drop [name]")
    .description("drops a scheme (current scheme is used if no name is given)")
    .action(runSchemesCommand("dropScheme"))

  commander
    .command("rename <name>")
    .description("renames current scheme to <name>")
    .action(runSchemesCommand("renameScheme"))

  commander
    .command("list")
    .description("lists all slots for current scheme")
    .action(runSchemesCommand("listSlots"))

  commander
    .command("pick")
    .description("brings up a menu to choose a slot interactively")
    .action(runSchemesCommand("pickSlot"))

  commander
    .command("get <idx>")
    .alias("go")
    .option('-i, --ignore-case', 'ignore case on fuzzy search')
    .description("change to slot <idx> (you can also give text for a fuzzy search)")
    .action(runSchemesCommand("getSlot"))

  commander
    .command("rm [idx]")
    .description("remove slot <idx>")
    .action(runSchemesCommand("removeSlot"))

  commander
    .command("swap <idx1> <idx2>")
    .description("swap the two slot numbers")
    .action(runSchemesCommand("swapSlots"))

  commander
    .command("set [idx] [path]")
    .description("set slot [idx] to [path] (cwd is used if no path is given) (next highest slot number is used if no idx is given)")
    .action(runSchemesCommand("saveSlot"))

  commander
    .command("setr [path]")
    .option('-C, --no-children', 'only add sub-directories one level deep')
    .description("recursively set all the slots to child directories using the next highest slot numbers (cwd is used if no path is given)")
    .action(runSchemesCommand("saveSlotsRecurse"))

  commander
    .command("clear")
    .description("remove all slots from the current scheme")
    .action(runSchemesCommand("clearSlots"))

  commander
    .command("compact")
    .description("reorder all slot numbers so there are no gaps")
    .action(runSchemesCommand("compactSlots"))
