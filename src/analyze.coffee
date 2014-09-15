_= require 'lodash'
esprima = require 'esprima'
require 'jshint'
scopeStates = _([])

Unknowable= {Unknowable:true}
RegisterClause =
  "ExpressionStatement":
    handle: (item,body)->

  "FunctionDeclaration":
    handle: (item,body)->
      prepend item
      makeBaseScope item.body,item.params
      body.actions.push (parentScope)->
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
  prepend analysis
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

hoist = (statement,hoisted,parent,key)->
  check = statement.type
  if check == "BlockStatement"
    _(statement.body).each(
      (bodyItem, key)-> hoist(bodyItem,hoisted,statement.body,key))
  if check=="VariableDeclaration"
    clone=_.clone(statement)

    clone.declarations = _.map clone.declarations,
      (item)->
        item=_.clone(item)
        item.init=null
        item
    hoisted.push(clone)
  if check=="FunctionDeclaration"
    hoisted.push(statement)
    parent[key] = "type": "EmptyStatement"
  if bodyBlocks.contains(check)
    hoist(statement.body,hoisted,statement,"body")
  if consequentBlocks.contains(check)
    hoist(statement.consequent,hoisted,statement,"consequent")
    hoist(statement.alternate,hoisted,statement,"alternate")
  if casesBlocks.contains(check)
    _(statement.cases).each(
      (caseItem, key)-> hoist(caseItem,hoisted,statement.cases,key))
  if blockBlocks.contains(check)
    hoist(statement.block,hoisted,statement,"block")
    hoist(statement.finalizer,hoisted,statement,"finalizer")
    _(statement.handlers).each(
      (bodyItem,key)-> hoist(bodyItem.body,hoisted,bodyItem.body,"body"))


prepend = (outer, hoisted = [])->
  _(outer.body).each (bodyItem)->
    hoist(bodyItem,hoisted)

  outer.body= _(hoisted).flatten().concat(outer.body).value()

module.exports={}