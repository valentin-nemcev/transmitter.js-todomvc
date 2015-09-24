'use strict'


{inspect} = require 'util'
Transmitter = require 'transmitter'


module.exports = class Todos extends Transmitter.Nodes.Record

  init: (tr) ->
    @nonBlankTodoListChannel.init(tr)
    @todoListWithCompleteChannel.init(tr)
    return this


  create: ->
    new Todo()


  @defineLazy 'nonBlankTodoList', ->
    new Transmitter.Nodes.List()

  @defineLazy 'nonBlankTodoListChannel', ->
    new NonBlankTodoListChannel(@nonBlankTodoList, @todoList)


  @defineLazy 'todoList', ->
    new Transmitter.Nodes.List()


  @defineLazy 'withComplete', ->
    new Transmitter.Nodes.List()

  @defineLazy 'todoListWithCompleteChannel', ->
    new TodoListWithCompleteChannel(@todoList, @withComplete)



class Todo extends Transmitter.Nodes.Record

  inspect: -> "[Todo #{inspect @labelVar.get()}]"

  init: (tr, defaults = {}) ->
    {label, isCompleted} = defaults
    @labelVar.init(tr, label) if label?
    @isCompletedVar.init(tr, isCompleted) if isCompleted?
    return this

  @defineVar 'labelVar'

  @defineVar 'isCompletedVar'



class NonBlankTodoListChannel extends Transmitter.Channels.CompositeChannel

  constructor: (@nonBlankTodoList, @todoList) ->

  @defineChannel ->
    new Transmitter.Channels.ListChannel()
      .inForwardDirection()
      .withOrigin @nonBlankTodoList
      .withDerived @todoList


  @defineLazy 'nonBlankTodoChannelVar', ->
    new Transmitter.ChannelNodes.ChannelVariable()


  @defineChannel ->
    new Transmitter.Channels.SimpleChannel()
      .fromSource @todoList
      .toConnectionTarget @nonBlankTodoChannelVar
      .withTransform (todoListPayload) =>
        todoListPayload.toSetVariable().map (todoList) =>
          @createNonBlankTodoChannel(todoList)
            .inBackwardDirection()
            .toTarget(@nonBlankTodoList)


  nonBlank = (str) -> !!str.trim()


  createNonBlankTodoChannel: (todos) ->
    new Transmitter.Channels.SimpleChannel()
      .fromDynamicSources(todo.labelVar for todo in todos)
      .withTransform (labelPayloads) ->
        labelPayloads.merge().map (labels) ->
          todos[i] for label, i in labels when nonBlank(label)



class TodoListWithCompleteChannel extends Transmitter.Channels.CompositeChannel

  constructor: (@todoList, @todoListWithComplete) ->


  @defineLazy 'withCompleteChannelVar', ->
    new Transmitter.ChannelNodes.ChannelVariable()


  @defineChannel ->
    new Transmitter.Channels.SimpleChannel()
      .inBackwardDirection()
      .fromSource @todoListWithComplete
      .toTarget @todoList
      .withTransform (todoListWithCompletePayload) =>
        todoListWithCompletePayload.map ([todo]) -> todo


  @defineChannel ->
    new Transmitter.Channels.SimpleChannel()
      .fromSource @todoList
      .toConnectionTarget @withCompleteChannelVar
      .withTransform (todoListPayload) =>
        todoListPayload.toSetVariable().map (todoList) =>
          @createWithCompleteChannel(todoList)
            .inForwardDirection()
            .toTarget(@todoListWithComplete)


  createWithCompleteChannel: (todos) ->
    new Transmitter.Channels.SimpleChannel()
      .fromDynamicSources(todo.isCompletedVar for todo in todos)
      .withTransform (isCompletedPayloads) ->
        isCompletedPayloads.merge().map (isCompletedStates) ->
          [todos[i], isCompleted] for isCompleted, i in isCompletedStates
