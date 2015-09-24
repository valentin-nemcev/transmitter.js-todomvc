'use strict'


Transmitter = require 'transmitter'


module.exports = class TodoStorage extends Transmitter.Nodes.Record

  constructor: (@name) ->

  setDefault: (serializedTodos) ->
    unless @todoListPersistenceVar.get()
      @todoListPersistenceVar.set(JSON.stringify(serializedTodos))
    return this

  load: (tr) ->
    @todoListPersistenceVar.originate(tr)


  @defineLazy 'todoListPersistenceVar', ->
    new Transmitter.Nodes.PropertyVariable(localStorage, @name)

  createTodosChannel: (todos) ->
    new TodoListPersistenceChannel(todos, @todoListPersistenceVar)



class SerializedTodoChannel extends Transmitter.Channels.CompositeChannel

  constructor: (@todo, @serializedTodoVar) ->

  @defineChannel ->
    new Transmitter.Channels.SimpleChannel()
      .inForwardDirection()
      .fromSources @todo.labelVar, @todo.isCompletedVar
      .toTarget @serializedTodoVar
      .withTransform ([labelPayload, isCompletedPayload]) =>
        labelPayload.merge(isCompletedPayload).map ([label, isCompleted]) ->
          {title: label, completed: isCompleted}


  @defineChannel ->
    new Transmitter.Channels.SimpleChannel()
      .inBackwardDirection()
      .fromSource @serializedTodoVar
      .toTargets @todo.labelVar, @todo.isCompletedVar
      .withTransform (serializedTodoPayload) =>
        serializedTodoPayload.map((serialized) ->
          {title, completed} = (serialized ? {})
          [title, completed]
        ).separate()


class TodoListPersistenceChannel extends Transmitter.Channels.CompositeChannel

  constructor: (@todos, @todoListPersistenceVar) ->


  @defineLazy 'todoPersistenceChannelVar', ->
    new Transmitter.ChannelNodes.ChannelVariable()


  @defineLazy 'serializedTodoList', ->
    new Transmitter.Nodes.List()

  @defineLazy 'serializedTodosVar', ->
    new Transmitter.Nodes.Variable()


  @defineChannel ->
    new Transmitter.Channels.VariableChannel()
      .withOrigin @serializedTodosVar
      .withDerived @todoListPersistenceVar
      .withMapOrigin (serializedTodos) ->
        JSON.stringify(serializedTodos)
      .withMapDerived (persistedTodos) ->
        JSON.parse(persistedTodos)


  serializedId = 0
  @defineChannel ->
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


  @defineChannel ->
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



  @defineChannel ->
    new Transmitter.Channels.SimpleChannel()
      .fromSource @serializedTodoList
      .toConnectionTarget @todoPersistenceChannelVar
      .withTransform (serializedTodoListPayload) =>
        serializedTodoListPayload.toSetVariable().map (v) =>
            @createTodoPersistenceChannel(v)


  createTodoPersistenceChannel: (serializedTodoVars) ->
    new Transmitter.Channels.CompositeChannel()
      .defineChannel =>
        new Transmitter.Channels.SimpleChannel()
          .inBackwardDirection()
          .fromSource @serializedTodosVar
          .toDynamicTargets(serializedTodoVars)
          .withTransform (serializedTodosPayload) ->
            serializedTodosPayload
              .map (todos) -> if todos?.length? then todos else []
              .separate()

      .defineChannel =>
        new Transmitter.Channels.SimpleChannel()
          .inForwardDirection()
          .fromDynamicSources(serializedTodoVars)
          .toTarget @serializedTodosVar
          .withTransform (serializedTodosPayloads) ->
            serializedTodosPayloads.merge()
