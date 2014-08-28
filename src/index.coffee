"use strict"

config = require './config'
jsh = require 'jshint'
_= require 'lodash'
path= require 'path'
defineRegex = /(?:^\s*|[}{\(\);,\n\?\&]\s*)define\s*\(\s*("[^"]+"\s*,\s*|'[^']+'\s*,\s*)?\s*(\[(\s*(("[^"]+"|'[^']+')\s*,|\/\/.*\r?\n|\/\*(.|\s)*?\*\/))*(\s*("[^"]+"|'[^']+')\s*,?\s*)?(\s*(\/\/.*\r?\n|\/\*(.|\s)*?\*\/)\s*)*\]|function\s*|{|[_$a-zA-Z\xA0-\uFFFF][_$a-zA-Z0-9\xA0-\uFFFF]*\))/g
globalsRegex = ['window(\.|\[[\"\'])', '([\"\']\])?\s*?=']
logger = null
envVars =_(require.cache).pairs().filter((item)-> item[0].indexOf('vars.js')!=-1&&item[1].parent.id.indexOf('jshint.js')!=-1).map((item)-> item[1].exports).first();
waiting={}
shims = null;
amdify=null;
registration = (mimosaConfig, register) ->
  logger = mimosaConfig.log
  amdify= mimosaConfig.amdify
  envVars = _(envVars).pairs().filter((vars)->_(amdify.envVars).contains(vars[0])).map((vars)-> vars[1]).flatten().value()
  amdify.globals=_(amdify.globals).map((val,key)->_(val).map((item)-> [item,key]).value()).flatten(true).object().value()
  shims = _(amdify.shim).pairs();
  register ['add','update','buildFile'], 'beforeCompile', _analizeFiles,  [mimosaConfig.extensions.javascript...]
  register ['add','update','buildFile'], 'beforeWrite', _applyRequireJSWrapper,  [mimosaConfig.extensions.javascript...]

_analizeFiles = (mimosaConfig, options, next) ->
  hasFiles = options.files?.length > 0
  return next() unless hasFiles
  _(options.files).each (file)->
    if file.inputFileText.match defineRegex
      if logger.isDebug()
        logger.debug "Not wrapping [[ #{file.inputFileName} ]], it already contains a define block"
    else
      relName= path.relative(amdify.path,file.inputFileName)
      jsh.JSHINT(file.inputFileText);
      _(jsh.JSHINT.data().implieds).pluck('name').each (implied)->
        glreg = new RegExp(globalsRegex[0]+implied+globalsRegex[1], 'g')
        if file.inputFileText.match(glreg)
          file.inputFileText= "var #{implied}; #{file.inputFileText.replace(glreg, implied+'=')}"
      jsh.JSHINT(file.inputFileText);
      file.shim = shims.filter((pair)-> pair[0] == relName).map((pair)-> pair[1]).first()||{}
      
      file.deps = _(jsh.JSHINT.data().implieds).pluck('name').value();
      file.exports = if file.shim.export then [file.shim.export] else _(jsh.JSHINT.data().globals).difference(envVars).filter((item)-> item!='undefined').value();
      waiting[file.shim.name||relName]=file
_applyRequireJSWrapper = (mimosaConfig, options, next) ->
  
  for file of waiting
    file.shim.deps = _(file.shim.deps||[]).map((dep)-> if waiting[dep] then [dep,waiting[dep]]).filter().value()
    file.deps = _(file.deps).map((dep)-> [dep,amdify.globals[dep]]).filter().value()
    file.outputFileText = _wrap(file,mimosaConfig.amdify)
  next()
_wrap = (file, amdify) ->
  start="define( #{_(file.deps).map((item)->item[1]).join(',')},#{_(file.shim.deps).map((item)->item[0])}"
  funcStart=",function( #{_(file.deps).map((item)->item[0]).join(',')}, #{_(file.shim.deps).map((val,index)-> '__amdify__'+index).join(',')} ){"
  imports = _(file.shim.deps).map((val,index)-> 
    _(val[1].exports).map(
      (exp)-> 
        if(exp.length>1)
          _(exp).intersect(file.deps).map((common)->"var #{common} = __amdify__#{index}.#{common};");
        else if(exp.length == 1)
          _(exp).intersect(file.deps).map((common)->"var #{common} = __amdify__#{index}")
      ).flatten().value()
    ).flatten().join('\n')

  if file.exports.length>1
    exports = "return { #{_(file.exports).map((exp)-> exp+':'+exp).join(',')} };"
  else if file.exports.length==1
    exports = "return #{_.first(file.exports)}"
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