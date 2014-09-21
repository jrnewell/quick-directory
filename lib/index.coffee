commander = require("commander")
# chalk = require("chalk")
# fs = require("fs")
path = require("path")
# _ = require("lodash")
util = require("./util")
config = require("./config")

# load plugins
util.requireFiles path.join(".", "lib", "plugins"), /(\.coffee|\.js)$/

commander
  .version(require("../package.json").version)

commander
  .command("*")
  .description("output usage information")
  .action(commander.help)

commander.parse(process.argv);