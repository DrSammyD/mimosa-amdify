_= require 'lodash'
esprima = require 'esprima'
require 'jshint'

bodyClause =
  "ExpressionStatement":
    handle: (item,model,body)->

  "FunctionDeclaration":
    handle: (item,model,body)->
      setScope(item.body,model)

  "VariableDeclarator":
    handle: (item,model,body)->

  "BlockStatement":
    handle: (item,model,body)->

  "VariableDeclaration":
    handle: (item,model,body)->

  "SwitchStatement":
    handle: (item,model,body)->

  "DoWhileStatement":
    handle: (item,model,body)->

  "WhileStatement":
    handle: (item,model,body)->

  "IfStatement":
    handle: (item,model,body)->

  "TryStatement":
    handle: (item,model,body)->

  "ThrowStatement":
    handle: (item,model,body)->

  "WithStatement":
    handle: (item,model,body)->

  "ForInStatement":
    handle: (item,model,body)->

  "ForStatement":
    handle: (item,model,body)->


start = (text, availDeps, predef)->
  analysis = esprima.parse(text,{range:true})
  model =
    scope: _({parent:{}})
    variableValues: _({})
    unwrapped: true
    garunteed: true

setScope= (body,params,model)->
  body.scope=_(body).filter (item) ->
    item.type == "VariableDeclaration"
  .pluck 'declarations'
  .flatten()
  .pluck 'name'
  .concat(
    _(body).filter (item) ->
      item.type == "FunctionDeclaration"
    .pluck 'id'
    .pluck 'name'
    .value()
  ).concat(
    _(params).pluck('name').value()
  ).value()
  body.scope.parent=model.scope



recursive = (body,model) ->
  setScope(body,model)
  model.scope = body.scope
  _(body)
  .sortBy (item) -> item.type != "FunctionDeclaration"
  .each (item) ->
    bodyClause[item.type].handle(item,model,body);

module.exports={}