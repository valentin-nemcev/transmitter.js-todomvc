'use strict'


{inspect} = require 'util'
Transmitter = require 'transmitter'


module.exports = class Todos

  constructor: ->
    @todoList = new Transmitter.Nodes.List()

    @nonBlankTodoList = new Transmitter.Nodes.List()
    @nonBlankTodoListChannel =
      new NonBlankTodoListChannel(@nonBlankTodoList, @todoList)

    @withComplete = new Transmitter.Nodes.List()
    @todoListWithCompleteChannel =
      new TodoListWithCompleteChannel(@todoList, @withComplete)


  init: (tr) ->
    @nonBlankTodoListChannel.init(tr)
    @todoListWithCompleteChannel.init(tr)
    return this


  create: ->
    new Todo()



class Todo

  inspect: -> "[Todo #{inspect @labelVar.get()}]"


  constructor: ->
    @labelVar = new Transmitter.Nodes.Variable()
    @isCompletedVar = new Transmitter.Nodes.Variable()


  init: (tr, defaults = {}) ->
    {label, isCompleted} = defaults
    @labelVar.init(tr, label) if label?
    @isCompletedVar.init(tr, isCompleted) if isCompleted?
    return this



class NonBlankTodoListChannel extends Transmitter.Channels.CompositeChannel

  constructor: (@nonBlankTodoList, @todoList) ->
    @nonBlankTodoChannelVar =
      new Transmitter.ChannelNodes.ChannelVariable()

    @defineListChannel()
      .inForwardDirection()
      .withOrigin @nonBlankTodoList
      .withDerived @todoList

    @defineSimpleChannel()
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
        Transmitter.Payloads.Variable.merge(labelPayloads).map (labels) ->
          todos[i] for label, i in labels when nonBlank(label)



class TodoListWithCompleteChannel extends Transmitter.Channels.CompositeChannel

  constructor: (@todoList, @todoListWithComplete) ->
    @defineSimpleChannel()
      .inBackwardDirection()
      .fromSource @todoListWithComplete
      .toTarget @todoList
      .withTransform (todoListWithCompletePayload) =>
        todoListWithCompletePayload.map ([todo]) -> todo

    @isCompletedList = new Transmitter.Nodes.List()
    @isCompletedDynamicChannelVar =
      new Transmitter.ChannelNodes.DynamicChannelVariable('sources', =>
        new Transmitter.Channels.SimpleChannel()
          .inForwardDirection()
          .toTarget(@isCompletedList)
          .withTransform (isCompletedPayload) ->
            isCompletedPayload.flatten()
      )

    @defineSimpleChannel()
      .fromSource @todoList
      .toConnectionTarget @isCompletedDynamicChannelVar
      .withTransform (todoListPayload) =>
        todoListPayload.map (todo) -> todo.isCompletedVar

    @defineSimpleChannel()
      .inForwardDirection()
      .fromSources @todoList, @isCompletedList
      .toTarget @todoListWithComplete
      .withTransform ([todosPayload, isCompletedPayload]) =>
        todosPayload.zip(isCompletedPayload)
