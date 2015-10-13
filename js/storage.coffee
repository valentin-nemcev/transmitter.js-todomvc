'use strict'


Transmitter = require 'transmitter'


module.exports = class TodoStorage extends Transmitter.Nodes.Record

  constructor: (@name) ->
    @todoListPersistenceVar =
      new Transmitter.Nodes.PropertyVariable(localStorage, @name)


  setDefault: (serializedTodos) ->
    unless @todoListPersistenceVar.get()
      @todoListPersistenceVar.set(JSON.stringify(serializedTodos))
    return this

  load: (tr) ->
    @todoListPersistenceVar.originate(tr)


  createTodosChannel: (todos) ->
    new TodoListPersistenceChannel(todos, @todoListPersistenceVar)



class SerializedTodoChannel extends Transmitter.Channels.CompositeChannel

  constructor: (@todo, @serializedTodoVar) ->
    @addChannel(
      new Transmitter.Channels.SimpleChannel()
        .inForwardDirection()
        .fromSources @todo.labelVar, @todo.isCompletedVar
        .toTarget @serializedTodoVar
        .withTransform ([labelPayload, isCompletedPayload]) =>
          labelPayload.merge(isCompletedPayload).map ([label, isCompleted]) ->
            {title: label, completed: isCompleted}
    )

    @addChannel(
      new Transmitter.Channels.SimpleChannel()
        .inBackwardDirection()
        .fromSource @serializedTodoVar
        .toTargets @todo.labelVar, @todo.isCompletedVar
        .withTransform (serializedTodoPayload) =>
          serializedTodoPayload.map((serialized) ->
            {title, completed} = (serialized ? {})
            [title, completed]
          ).separate()
    )


class TodoListPersistenceChannel extends Transmitter.Channels.CompositeChannel

  serializedId = 0

  constructor: (@todos, @todoListPersistenceVar) ->
    @serializedTodoList = new Transmitter.Nodes.List()
    @serializedTodosVar = new Transmitter.Nodes.Variable()

    @addChannel(
      new Transmitter.Channels.VariableChannel()
        .withOrigin @serializedTodosVar
        .withDerived @todoListPersistenceVar
        .withMapOrigin (serializedTodos) ->
          JSON.stringify(serializedTodos)
        .withMapDerived (persistedTodos) ->
          JSON.parse(persistedTodos)
    )

    @addChannel(
      new Transmitter.Channels.ListChannel()
        .withOrigin @todos.todoList
        .withMapOrigin (todo) ->
          serializedVar = new Transmitter.Nodes.Variable()
          serializedVar.todo = todo
          id = serializedId++
          serializedVar.inspect = -> "[serializedTodoVar#{id} #{@todo}]"
          return serializedVar
        .withDerived @serializedTodoList
        .withMapDerived (serializedVar) =>
          todo = @todos.create()
          serializedVar.todo = todo
          return todo
        .withMatchOriginDerived (todo, serializedTodoVar) ->
          todo == serializedTodoVar.todo
        .withOriginDerivedChannel (todo, serializedTodoVar) ->
          new SerializedTodoChannel(todo, serializedTodoVar)
    )

    @addChannel(
      new Transmitter.Channels.SimpleChannel()
        .inBackwardDirection()
        .fromSource @serializedTodosVar
        .toTarget @serializedTodoList
        .withTransform (serializedTodosPayload) ->
          serializedTodosPayload.toSetList().map ->
            v = new Transmitter.Nodes.Variable()
            id = serializedId++
            v.inspect = -> "[serializedTodoVar#{id} #{@todo}]"
            return v
    )

    @todoPersistenceForwardChannelVar =
      new Transmitter.ChannelNodes.DynamicChannelVariable('sources', =>
        new Transmitter.Channels.SimpleChannel()
          .inForwardDirection()
          .toTarget @serializedTodosVar
          .withTransform (serializedTodosPayloads) ->
            serializedTodosPayloads.flatten()
      )

    @todoPersistenceBackwardChannelVar =
      new Transmitter.ChannelNodes.DynamicChannelVariable('targets', =>
        new Transmitter.Channels.SimpleChannel()
          .inBackwardDirection()
          .fromSource @serializedTodosVar
          .withTransform (serializedTodosPayload) ->
            serializedTodosPayload.toSetList().unflatten()
      )

    @addChannel(
      new Transmitter.Channels.SimpleChannel()
        .fromSource @serializedTodoList
        .toConnectionTargets \
          @todoPersistenceBackwardChannelVar, @todoPersistenceForwardChannelVar
    )
