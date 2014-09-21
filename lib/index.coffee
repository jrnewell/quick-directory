commander = require("commander")
chalk = require("chalk")
fs = require("fs")
path = require("path")
_ = require("lodash")

# load plugins

commander
  .version(require("../package.json").version)

commander
  .command("*")
  .description("output usage information")
  .action(commander.help)

commander.parse(process.argv);