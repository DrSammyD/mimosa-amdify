_= require 'lodash'
esprima = require 'esprima'
require 'jshint'
scopeStates = _([])

Unknowable= {Unknowable:true}

setProperty = (scope,result,propertyPath)->
  state=getState(_.first(propertyPath))
  _(propertyPath.slice(0,-1)).each (prop)->
    state = state?[prop]?.current
  if state
    state[propertyPath.slice(-1)] = state[propertyPath.slice(-1)]||{}
    state[propertyPath.slice(-1)].current = result

getState = (scope,topProp)->
  while(!scope[topProp] && scope.parent)
    scope = scope.parent
  scopeStates.filter (scopeState)->
    scopeState.scope==scope
  .pluck 'state'

RegisterClause =
  "ExpressionStatement":
    handle: (item,body)->

  "FunctionDeclaration":
    handle: (item,body)->
      setScope(item.body)
      body.actions.push (state, scope)->
        setState(state,scope,item,dec.id.name)

  "VariableDeclaration":
    handle: (item,body)->
      _(item.declarations).each (dec)->
        result = RegisterClause.ExpressionStatement.handle(dec.init,body)
        body.actions.push (state)->
          setState(state,result(state),dec.id.name)
      _.last(body.actions)

  "SwitchStatement":
    handle: (item,body)->

  "DoWhileStatement":
    handle: (item,body)->

  "WhileStatement":
    handle: (item,body)->

  "IfStatement":
    handle: (item,body)->

  "TryStatement":
    handle: (item,body)->

  "ThrowStatement":
    handle: (item,body)->

  "WithStatement":
    handle: (item,body)->

  "ForInStatement":
    handle: (item,body)->

  "ForStatement":
    handle: (item,body)->


start = (text, availDeps, predef)->
  analysis = esprima.parse(text,{range:true})
  setScope(analysis.body)
  recursive(analysis.body)

setScope= (body,params=[],parentScope=null)->
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
  body.scope.parent=parentScope
  scopeStates.push({scope:body.scope,state:{}})



recursive = (body) ->
  body.actions=body.actions||[]
  _(body)
  .map((item)-> if item.type =="BlockStatement" then item.body else item)
  .flatten()
  .sortBy (item) -> item.type != "FunctionDeclaration"
  .each (item) ->
    bodyClause[item.type].handle(item,body);

module.exports={}