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
      hoist item
      makeBaseScope item.body,item.params
      body.actions.push  (parentScope)->
        setScope body,parentScope
        setProperty parentScope,item, item.id.name

  "VariableDeclaration":
    handle: (item,body)->
      _(item.declarations).each (dec)->
        result = RegisterClause.ExpressionStatement.handle(dec.init,body)
        body.actions.push (parentScope)->
          setProperty(parentScope,result(state),dec.id.name)
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
  analysis = esprima.parse text,{range:true}
  hoist analysis
  makeBaseScope analysis.body
  recursive analysis.body


getScopeVars= (body,params=[])->
  _(body).filter (item) ->
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
    _(body).filter (item) ->
      potentialBlocks.contains item.type
    .map (item)->
      getScopeVars (item.consequent)?.body||
      [(item.consequent)]||
      (item.body)?.body||
      [(item.body)]
    .value()
  ).concat(
    _(params).pluck('name').value()
  ).value()

makeBaseScope = (body,params=[])->
  body.scope = getScopeVars body,params


setScope = (body,parentScope = null)->
  scope = _.clone(body.scope)
  scope.parent=parentScope
  scopeStates.push {scope:scope,state:{}}
  return scope;

recursive = (body) ->
  body.actions=body.actions||[]
  _(body)
  .map (item)-> if item.type =="BlockStatement" then item.body else item
  .flatten()
  .sortBy (item) -> item.type != "FunctionDeclaration"
  .each (item) ->
    bodyClause[item.type].handle item,body

bodyBlocks = _(["DoWhileStatement"
  "WhileStatement"
  "ForInStatement"
  "ForStatement"])

blockBlocks = _([
  "TryStatement"])

consequentBlocks =_(["IfStatement"])

casesBlocks =_(["SwitchStatement"])

hoist = (outer, hoisted)->
  if outer.body
    base = _(outer.body)
    .map (item)->
      if item.type =="BlockStatement" then item.body else item
    .flatten()
    hoisted.push(
      base.filter (item)->
        item.type=="FunctionDeclaration"
      .value()
    )
    base.filter (item) ->
      bodyBlocks.contains(item.type)
    .each (item) ->
      if hoist(item.block,hoisted)
      then item.body={"type": "BlockStatement","body": []}

    base.filter (item) ->
      blockBlocks.contains(item.type)
    .each (item) ->
      _([item]).concat(item.handlers).each (item) ->
        if hoist(item.block,hoisted)

    base.filter (item) ->
      consequentBlocks.contains(item.type)
    .each (item) ->
      if hoist(item.consequent,hoisted)
      then item.consequent={"type": "BlockStatement","body": []}
      if alternate && hoist(item.alternate,hoisted)
      then item.alternate={"type": "BlockStatement","body": []}
    false
  else if outer.type == "FunctionDeclaration"
    hoisted.push(outer)
    true
  else if outer.type = ""

betterHoist = (statement,hoisted,parent,key)->
  check =statement.type
  if check=="BlockStatement"
    then _(statement.body).each
      (bodyItem, key)-> betterHoist(bodyItem,hoisted,statement.body,key)
  if check=="FunctionDeclaration" then
    hoisted.push(statement)
    parent[key] = "type": "EmptyStatement"
  if bodyBlocks.contains(check)
    betterHoist(statement.body,hoisted,statement,"body")
  if consequentBlocks.contains(check)
    betterHoist(statement.consequent,hoisted,statement,"consequent")
    betterHoist(statement.alternate,hoisted,statement,"alternate")
  if casesBlocks.contains(check)
    _(statement.cases).each
      (caseItem, key)-> betterHoist(caseItem,hoisted,statement.cases,key)
  if blockBlocks.contains(check)
    


prepend = (outer, hoisted = [])->
  hoist(outer,hoisted)
  base = _(outer.body)
  .map (item)->
    if item.type =="BlockStatement" then item.body else item
  .flatten()

  outer.body= _.flatten(hoisted).concat(
    base.filter (item)-> item.type != "FunctionDeclaration"
    .value()
  )

module.exports={}