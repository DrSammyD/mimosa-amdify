#coffeehint no_backticks:{level:"ignore"}

_= require 'lodash'
esprima = require 'esprima'
require 'jshint'
scopeStates = _([])

Unknowable= {Unknowable:true}


Statements =
  "ExpressionStatement":
    handle: (item,parentBody)->

  "FunctionDeclaration":
    handle: (item,parentBody)->
      prepend(item)
      makeBaseScope item.body,item.params
      parentBody.actions.push (parentScope)->
        prepend(item)
        setScope parentBody,parentScope
        setVariable parentScope,item,item.id.name
        null

  "VariableDeclaration":
    handle: (item,parentBody)->
      _(item.declarations).each (dec)->
        result = getExpression(dec.init,parentBody)
        parentBody.actions.push (parentScope)->
          setVariable(parentScope,result(parentScope),dec.id.name)
          null

  "SwitchStatement":
    handle: (item,parentBody)->

  "DoWhileStatement":
    handle: (item,parentBody)->

  "WhileStatement":
    handle: (item,parentBody)->

  "IfStatement":
    handle: (item,parentBody)->

  "TryStatement":
    handle: (item,parentBody)->

  "ThrowStatement":
    handle: (item,parentBody)->

  "WithStatement":
    handle: (item,parentBody)->

  "ForInStatement":
    handle: (item,parentBody)->

  "ForStatement":
    handle: (item,parentBody)->

Expressions=
  "FunctionExpression":
    handle: (item,parentBody)->
      prepend(item)
      makeBaseScope item.body,item.params
      (parentScope)->
        prepend item
        setScope body,parentScope
        item
  "Identifier":
    handle: (item,parentBody)->
      (parentScope)->
        getVariable(parentScope,item.name)
  "MemberExpression":
    handle: (item,parentBody)->
      object=getExpression(item.object,parentBody)
      property=getExpression(item.property,parentBody)
      (parentScope)->
        object(parentScope)[property(parentScope)]
  "ObjectExpression":
    handle:(item,parentBody)->
      props=_(item.properties).chain().map (item)->
        [getKey(item.key,parentBody),
        getExpression(item.value,parentBody)]
      (parentScope)->
        props.map (pair)->
          [pair[0](parentScope),pair[1](parentScope)]
        .object()
        .value()
  "ArrayExpression":
    handle:(item,parentBody)->
      props=_(item.properties).chain().map (item)->
        if item
          getExpression(item.value,parentBody)
      (parentScope)->
        props.map (item)->
          if item
            item(parentScope)
        .value()
  "Literal":
    handle:(item,parentBody)->
      (parentScope)->
        item.value
  "LogicalExpression":
    handle (item, parentBody)->
      left = getExpression(item.left, parentBody)
      right = getExpression(item.right, parentBody)
      (parentScope)->
        logicWithOperator(left(parentScope),right(parentScope),item.operator)
  "UnaryExpression":
    handle (item, parentBody)->
      argument = getExpression(item.argument, parentBody)
      (parentScope)->
        unaryWithOperator(argument(parentScope),item.operator)
  "UpdateExpression":
    handle (item, parentBody)->
      object = getObjectExpression(item.argument,parentBody)
      property = getUpdateExpression(item.argument,parentBody,item.operator)
      (parentScope)->
        updateWithOperator(argument(parentScope),item.operator)
  "AssignmentExpression":
    handle: (item,parentBody)->
      result = getExpression(item.right,parentBody)
      object = getObjectExpression(item.left,parentBody)
      property = getAssignmentExpression(item.left,parentBody,item.operator)
      (parentScope)->
        property(parentScope,result,object)



getExpression= (item,parentBody)->
  Expressions[item.type].handle(item,parentBody)
getKey=(item,parentBody)->
  (parentBody)->
    item.name||item.value
getObjectExpression= (item,parentBody)->
  if item.type=="MemberExpression"
    getExpression(item.object,parentBody)
getAssignmentExpression=(item,parentBody,operator)->
  if item.type=="MemberExpression"
    prop= getExpression(item.property,parentBody)
    (parentScope,result,object)->
      assignWithOperator object(parentScope), prop(parentScope),
      operator, result(parentScope)
  if item.type=="Identifier"
    (parentScope,result,object)->
      setVariable(parentScope,result(parentScope),item.name,operator)
getUpdateExpression=(item,parentBody,operator)->
  if item.type=="MemberExpression"
    prop= getExpression(item.property,parentBody)
    (parentScope,object)->
      updateWithOperator object(parentScope), prop(parentScope), operator
  if item.type=="Identifier"
    (parentScope,object)->
      updateVariable(parentScope,item.name,operator)

assignWithOperator=(object,prop,operator,result)->
  switch(operator)
    when "="
      `object[prop]=result`
    when "+="
      `object[prop]+=result`
    when "-="
      `object[prop]-=result`
    when "*="
      `object[prop]*=result`
    when "/="
      `object[prop]/=result`
    when "%="
      `object[prop]%=result`
    when "<<="
      `object[prop]<<=result`
    when ">>="
      `object[prop]>>=result`
    when ">>>="
      `object[prop]>>>=result`
    when "&="
      `object[prop]&=result`
    when "^="
      `object[prop]^=result`
    when "|="
      `object[prop]|=result`

binaryWithOperator=(left,right,operator)->
  switch(operator)
    when "=="
      `left==right`
    when "!="
      `left!=right`
    when "==="
      `left===right`
    when "!=="
      `left!==right`
    when "<"
      `left<right`
    when "<="
      `left<=right`
    when ">"
      `left>right`
    when ">="
      `left>=right`
    when "<<"
      `left<<right`
    when ">>"
      `left>>right`
    when ">>>"
      `left>>>right`
    when "+"
      `left+right`
    when "-"
      `left-right`
    when "*"
      `left*right`
    when "/"
      `left/right`
    when "%"
      `left%right`
    when "|"
      `left|right`
    when "^"
      `left^right`
    when "^"
      `left^right`
    when "in"
      `left in right`
    when "instanceof"
      `left instanceof right`

updateWithOperator=(object,prop,operator,prefix)->
  switch(operator)
    when "--"
      if prefix then --object[prop] else object[prop]--
    when "++"
      if prefix then ++object[prop] else object[prop]++

logicWithOperator=(left,right,operator)->
  switch(operator)
    when "||"
      left||right
    when "&&"
      left&&right

unaryWithOperator=(argument,operator)->
  switch(operator)
    when "-"
      `-argument`
    when "+"
      `+argument`
    when "!"
      `!argument`
    when "~"
      `~argument`
    when "typeof"
      `typeof argument`
    when "void"
      `void argument`
    when "delete"
      `delete argument`

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
    _(params).pluck('name').value()
  ).value()

makeBaseScope = (body,params=[])->
  body.scope = getScopeVars body,params

setVariable = (scope,result,variable,operator)->
  scopeState=getScopeState(scope,variable)
  if scopeState.scope.indexOf(variable) == -1
    scopeState.scope.push(variable)
  assignWithOperator(scopeState.state,variable,operator,result)

updateVariable = (scope,result,variable,operator)->
  scopeState=getScopeState(scope,variable)
  updateWithOperator(scopeState.state,variable,operator)

getVariable = (scope,variable)->
  getScopeState(scope,variable).state

getScopeState = (scope,variable)->
  while(!scope[variable] && scope.parent)
    scope = scope.parent
  scopeStates.first (scopeState)->
    scopeState.scope==scope
  .first()||scopeStates.first()

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
  if outer.hoisted
    _(outer.body).each (bodyItem)->
      hoist(bodyItem,hoisted)

    outer.body= _(hoisted).flatten().concat(outer.body).value()
    outer.hoisted=true

module.exports={}