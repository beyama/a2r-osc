module.exports = process.env.OSC_COV ?
  require("./lib-cov/a2r-osc") :
  (require.extensions[".coffee"] ? require("./src/a2r-osc") : require("./lib/a2r-osc"))
