'use strict'


Transmitter = require 'transmitter'


class exports.Todo extends Transmitter.Nodes.Record

  inspect: -> "[Todo #{inspect @labelVar.get()}]"

  init: (tr, defaults = {}) ->
    {label, isCompleted} = defaults
    @labelVar.init(tr, label) if label?
    @isCompletedVar.init(tr, isCompleted) if isCompleted?
    return this

  @defineVar 'labelVar'

  @defineVar 'isCompletedVar'



class exports.NonBlankTodoListChannel extends Transmitter.Channels.CompositeChannel

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
      .withTransform (todoList) =>
        Transmitter.Payloads.Variable.setLazy( =>
          channel = if todoList?
            @createNonBlankTodoChannel(todoList.get())
          else
            new Transmitter.Channels.PlaceholderChannel()
          channel
            .inBackwardDirection()
            .toTarget(@nonBlankTodoList)
        )


  nonBlank = (str) -> !!str.trim()


  createNonBlankTodoChannel: (todos) ->
    if todos.length
      channel = new Transmitter.Channels.SimpleChannel()
      channel.fromSources(todo.labelVar for todo in todos)
      channel.withTransform (labels) ->
        Transmitter.Payloads.List.setLazy ->
          nonBlankTodos =
            todos[i] for label, i in labels.values() when nonBlank(label.get())
          return nonBlankTodos
    else
      new Transmitter.Channels.ConstChannel()
        .withPayload ->
          Transmitter.Payloads.List.setConst([])



class exports.TodoListWithCompleteChannel extends Transmitter.Channels.CompositeChannel

  constructor: (@todoList, @todoListWithComplete) ->


  @defineLazy 'withCompleteChannelVar', ->
    new Transmitter.ChannelNodes.ChannelVariable()


  @defineChannel ->
    new Transmitter.Channels.SimpleChannel()
      .inBackwardDirection()
      .fromSource @todoListWithComplete
      .toTarget @todoList
      .withTransform (todoListWithComplete) =>
        todoListWithComplete.map ([todo]) -> todo


  @defineChannel ->
    new Transmitter.Channels.SimpleChannel()
      .fromSource @todoList
      .toConnectionTarget @withCompleteChannelVar
      .withTransform (todoList) =>
        Transmitter.Payloads.Variable.setLazy( =>
          channel = if todoList?
            @createWithCompleteChannel(todoList.get())
          else
            new Transmitter.Channels.PlaceholderChannel()
          channel
            .inForwardDirection()
            .toTarget(@todoListWithComplete)
        )


  createWithCompleteChannel: (todos) ->
    if todos.length
      channel = new Transmitter.Channels.SimpleChannel()
      channel.fromSources(todo.isCompletedVar for todo in todos)
      channel.withTransform (isCompletedList) ->
        Transmitter.Payloads.List.setLazy ->
          for isCompleted, i in isCompletedList.values()
            [todos[i], isCompleted.get()]
    else
      new Transmitter.Channels.ConstChannel()
        .withPayload ->
          Transmitter.Payloads.List.setConst([])
