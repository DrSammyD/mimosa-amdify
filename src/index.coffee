"use strict"

config = require './config'
track = require './track'
clean = require './clean'
jsh = require 'jshint'
_= require 'lodash'
path= require 'path'
stripCommentsRegex = /((\/\/.*$)|(\/\*[\s\S]*?\*\/))/mg
defineRegex = /(?:^\s*|[}{\(\);,\n\?\&]\s*)define\s*\(\s*("[^"]+"\s*,\s*|'[^']+'\s*,\s*)?\s*(\[(\s*(("[^"]+"|'[^']+')\s*,|\/\/.*\r?\n|\/\*(.|\s)*?\*\/))*(\s*("[^"]+"|'[^']+')\s*,?\s*)?(\s*(\/\/.*\r?\n|\/\*(.|\s)*?\*\/)\s*)*\]|function\s*|{|[_$a-zA-Z\xA0-\uFFFF][_$a-zA-Z0-9\xA0-\uFFFF]*\))/g
globalsRegex = ["window(\\.|\\[[\\\"\\\'])", "([\\\"\\\']\\])?\\s*?="]
globalsUsageReggex =["window(\\.|\\[[\\\"\\\'])", "([\\\"\\\']\\])?"]
logger = null
reqEnvVars =_(require.cache).pairs().filter((item)-> item[0].indexOf('vars.js')!=-1&&item[1].parent.id.indexOf('jshint.js')!=-1).map((item)-> item[1].exports).first()
envVars = []
jshintResults={}
shims = null
amdify=null
registration = (mimosaConfig, register) ->
  logger = mimosaConfig.log
  amdify = mimosaConfig.amdify
  envVars = _(reqEnvVars).pairs().filter((vars)->_(amdify.envVars).contains(vars[0])).map((vars)-> _.keys(vars[1])).flatten().value()
  amdify.globals=_(amdify.globals).map((val,key)->_(val).map((item)-> [item,key]).value()).flatten(true).object().value()
  shims = _(amdify.shim).pairs()
  jshintResults = track.getPreviousAnalyzedFileList(mimosaConfig)
  register ['add','update','buildFile'], 'read', _analizeFiles,  [mimosaConfig.extensions.javascript...]
  register ['add','update','buildExtension'], 'beforeWrite', _applyRequireJSWrapper,  [mimosaConfig.extensions.javascript...]

_setJshintResult = (file, shim, relName)->
  jsh.JSHINT(file.inputFileText,{latedef:false},{})
  result = {shim:shim}
  result.replacements=[]
  result.usage = []
  text = file.inputFileText
  if _(jsh.JSHINT.data().implieds).pluck('name').any((item)-> return item == "window")
    _(jsh.JSHINT.data().implieds).pluck('name').concat(_(amdify.globals).keys().value()).difference(envVars).concat(_.flatten([shim.export||[]])).each (implied)->
      glreg = new RegExp(globalsRegex[0]+implied+globalsRegex[1], 'g')
      if text.replace(stripCommentsRegex,'').match(glreg)
        result.replacements.push(implied)
        text= "var #{implied}; #{text.replace(glreg, implied+'=')}"
  _(amdify.globals).keys().each (global)->
    glreg = new RegExp(globalsUsageReggex[0]+global+globalsUsageReggex[1], 'g')
    if text.replace(stripCommentsRegex,'').match(glreg) and !text.match(/var\s+?window[\W]/)
      result.usage.push(global)
      text= text.replace(glreg, global)
  jsh.JSHINT(text,{latedef:false},{})
  file = result

  file.deps = _(jsh.JSHINT.data().implieds).pluck('name').difference(envVars).value()
  if (jshglobals=_(jsh.JSHINT.data().globals).filter((item)-> item!='undefined').value()).length
    actualGlobals= _(text.match(new RegExp("\\S[\\n\\s]+?("+jshglobals.join('|')+")[\\s\\n]*?=",'g')))
    .filter((exp)->exp.indexOf('.')!=1).uniq()
    .map((exp)-> exp.replace(/\S[\n\s]+?/,'').replace(/[\s\n]*?=/,'')).value()
  else
    actualGlobals=[]
  file.exports = if file.shim.export then _.flatten([file.shim.export]) else actualGlobals
  jshintResults[file.shim.name||relName]=file

_analizeFiles = (mimosaConfig, options, next) ->
  hasFiles = options.files?.length > 0
  return next() unless hasFiles
  _(options.files).filter (file)->
    maybe=_([amdify.includePaths]).flatten().map (include)->
      relative= path.relative(path.relative(amdify.path,file.inputFileName), include)
      if !_(relative.split(path.sep)).filter((item) ->
        item isnt ".."
      ).value().length then relative.match(/\.\./g) else if relative=='' then [] else null
    .filter((include)-> include || include == 0)
    .map (item)-> item.length

    (_([amdify.excludePaths]).flatten().map (exclude)->
      relative = path.relative(path.relative(amdify.path,file.inputFileName), exclude)
      if !_(relative.split(path.sep)).filter((item) ->
        item isnt ".."
      ).value().length then relative.match(/\.\./g) else if relative=='' then [] else null
    .filter()
    .map (item)-> item.length
    .min().value() >= maybe.min().value()) && (maybe.value().length || !amdify.includePaths.length)

  .each (file)->
    if file.inputFileText.match defineRegex
      if logger.isDebug()
        logger.debug "Not wrapping [[ #{file.inputFileName} ]], it already contains a define block"
    else
      relName= path.relative(amdify.path,file.inputFileName).split(path.sep).join('/')
      shim = shims.filter((pair)-> pair[0] == relName).map((pair)-> pair[1]).first()||{}
      _setJshintResult(file,shim,relName)
  track.track(mimosaConfig,jshintResults)
  next()

_applyRequireJSWrapper = (mimosaConfig, options, next) ->
  hasFiles = options.files?.length > 0
  return next() unless hasFiles
  _(options.files).each (file)->    
    relName= path.relative(amdify.path,file.inputFileName).split(path.sep).join('/')
    shim = shims.filter((pair)-> pair[0] == relName).map((pair)-> pair[1]).first()||{}
    fileAnalysis= jshintResults[shim.name||relName]
    if fileAnalysis
      fileAnalysis.shim.deps = _(fileAnalysis.shim.deps||[]).map((dep)-> if jshintResults[dep] then [dep,jshintResults[dep]]).filter().value()
      fileAnalysis.deps = _(fileAnalysis.deps).map((dep)-> [dep,amdify.globals[dep]]).filter().value()
      file.outputFileText = _wrap(file, fileAnalysis,mimosaConfig.amdify)
  next()

_wrap = (file, fileAnalysis) ->

  _(fileAnalysis.replacements).each (implied)->
    glreg = new RegExp(globalsRegex[0]+implied+globalsRegex[1], 'g')
    file.outputFileText= "var #{implied}; #{file.outputFileText.replace(glreg, implied+'=')}"
  _(fileAnalysis.usage).each (global)->
    glreg = new RegExp(globalsUsageReggex[0]+global+globalsUsageReggex[1], 'g')
    file.outputFileText= file.outputFileText.replace(glreg, global)
  start="define( #{_(fileAnalysis.deps).map((item)->item[1]).join(',')},#{_(fileAnalysis.shim.deps).map((item)->item[0])}"
  funcStart=",function( #{_(fileAnalysis.deps).map((item)->item[0]).join(',')}, #{_(fileAnalysis.shim.deps).map((val,index)-> '__amdify__'+index).join(',')} ){"
  imports = _(fileAnalysis.shim.deps).map((val,index)-> 
    _(val[1].exports).map(
      (exp)->
        if(exp.length>1)
          _(exp).intersect(fileAnalysis.deps).map((common)->"var #{common} = __amdify__#{index}.#{common};")
        else if(exp.length == 1)
          _(exp).intersect(fileAnalysis.deps).map((common)->"var #{common} = __amdify__#{index}")
      ).flatten().value()
    ).flatten().join('\n')

  if fileAnalysis.exports.length>1
    exports = "return { #{_(fileAnalysis.exports).map((exp)-> exp+':'+exp).join(',')} };"
  else if fileAnalysis.exports.length==1
    exports = "return #{_.first(fileAnalysis.exports)}"
  """
  #{start}#{funcStart}
  #{imports}
  #{file.outputFileText}
  #{exports}
  });
  """

module.exports =
  registration: registration
  defaults:     config.defaults
  placeholder:  config.placeholder
  validate:     config.validate