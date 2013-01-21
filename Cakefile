fs = require "fs"
{print} = require "sys"
{spawn, exec} = require "child_process"

binPath = "./node_modules/.bin"

streamDataHandler = (data)-> print data

compileLib = (callback)->
  options = ["-c", "-o", "lib", "src"]
  coffee = spawn "#{binPath}/coffee", options
  coffee.stderr.on 'data', streamDataHandler
  coffee.stdout.on 'data', streamDataHandler
  coffee.on 'exit', (code) -> callback?() if code is 0

removeLib = (callback)->
  exec "rm -rf ./lib/*", -> callback?()

makeCoverage = (callback)->
  options = ["lib", "lib-cov"]
  jscov = spawn "jscoverage", options
  jscov.stderr.on 'data', streamDataHandler
  jscov.stdout.on 'data', streamDataHandler
  jscov.on 'exit', (code) -> callback?() if code is 0

removeCoverage = (callback)->
  exec "rm -rf ./lib-cov", -> callback?()

runTests = (callback)->
  options = [
    "--reporter",
    "dot",
    "-c",
    "--compilers",
    "coffee:coffee-script"
  ]

  process.env.NODE_ENV = "test"
  mocha = spawn "#{binPath}/mocha", options
  mocha.stderr.on 'data', streamDataHandler
  mocha.stdout.on 'data', streamDataHandler
  mocha.on 'exit', (code) -> callback?() if code is 0

runCoverage = (callback)->
  options = [
    "--reporter",
    "html-cov",
    "--compilers",
    "coffee:coffee-script"
  ]

  process.env.NODE_ENV = "test"
  process.env.OSC_COV  = 1
  mocha = spawn "#{binPath}/mocha", options
  fileStream = fs.createWriteStream "coverage.html"
  mocha.stderr.on 'data', streamDataHandler
  mocha.stdout.pipe(fileStream)
  mocha.on 'exit', (code) -> callback?() if code is 0

buildClient = (callback)->
  srcStream = fs.createReadStream("./src/a2r-osc/osc.coffee", encoding: "utf8")
  outStream = fs.createWriteStream("./browser/osc.js", encoding: "utf8")

  coffee = spawn "#{binPath}/coffee", ["-s", "-p"]
  coffee.stderr.on 'data', streamDataHandler

  # pipe js to out stream
  coffee.stdout.pipe(outStream)

  # skip node specific parts of code
  srcStream.on "data", (data)->
    ignore = false

    for line in data.split("\n")
      if /^#end_only_node/.test line
        ignore = false
      else if /^#only_node/.test line
        ignore = true
      else if not ignore
        coffee.stdin.write(line)
        coffee.stdin.write("\n")

  srcStream.on "close", -> coffee.stdin.end()

  # compress 
  outStream.on "close", ->
    uglify = spawn "#{binPath}/uglifyjs", ["-c", "-m", "-o", "./browser/osc.min.js", "./browser/osc.js"]
    uglify.stderr.on 'data', streamDataHandler
    uglify.stdout.on 'data', streamDataHandler
    uglify.on 'exit', (code) ->
      if code is 0
        exec "#{binPath}/coffee -o browser/ -c test/osc.test.coffee", -> callback?()

task "clean", "Remove JavaScript files from lib and lib-cov directory", ->
  removeLib -> removeCoverage()

task "build", "Build JavaScript files", -> removeLib -> compileLib()

task "browser", "Build browser version", -> buildClient()

task "test", "Run tests", -> runTests()

task "coverage", "Run coverage test", ->
  removeLib -> removeCoverage -> compileLib -> makeCoverage -> runCoverage()
