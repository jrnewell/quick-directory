commander = require("commander")
# chalk = require("chalk")
fs = require("fs")
path = require("path")
# _ = require("lodash")
util = require("./util")
config = require("./config")
cmds = require("./commands")

{runCommand, emitter} = util

# load plugins
util.requireFiles path.join(__dirname, "plugins"), /(\.coffee|\.js)$/

defaultCommands =

  # eval "$(./app.js init)"
  init: () ->
    console.log """
    function _qdwrap() {
      local cmd newPath
      cmd="$1"
      shift
      newPath=$(/Users/james/node.js/quick-directory/app.js "$cmd" "$@")
      if [ $? -eq 0 ]; then
        cd "$newPath"
      fi
    }
    function q() {
      _qdwrap get $1
    }
    function qq() {
      _qdwrap pick
    }
    function hh() {
      _qdwrap pick-hist $1
    }
    function cd()
    {
      builtin cd "$@"
      if [[ $? -eq 0 ]]; then
        (/Users/james/node.js/quick-directory/app.js _cd &)
      fi
    }
    """
    programDone()

  _cd: () ->
    _path = process.cwd()
    return unless fs.existsSync _path
    emitter.emit "cd:path", _path
    programDone()

cmds.extend defaultCommands

commander
  .version(require("../package.json").version)

commander
  .command("init")
  .action(runCommand("init"));

commander
  .command("_cd")
  .action(runCommand("_cd"));

commander
  .command("*")
  .description("output usage information")
  .action(commander.help)

commander.parse(process.argv);