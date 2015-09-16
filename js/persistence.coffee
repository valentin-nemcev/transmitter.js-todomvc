'use strict'


Transmitter = require 'transmitter'

{Todo} = require './model'


class SerializedTodoChannel extends Transmitter.Channels.CompositeChannel

  constructor: (@todo, @serializedTodoVar) ->

  @defineChannel ->
    new Transmitter.Channels.SimpleChannel()
      .inForwardDirection()
      .fromSource @todo.labelVar
      .fromSource @todo.isCompletedVar
      .toTarget @serializedTodoVar
      .withTransform (payloads) =>
        label = payloads.get(@todo.labelVar)
        isCompleted = payloads.get(@todo.isCompletedVar)
        Transmitter.Payloads.Variable.setLazy ->
          {title: label.get(), completed: isCompleted.get()}


  @defineChannel ->
    new Transmitter.Channels.SimpleChannel()
      .inBackwardDirection()
      .fromSource @serializedTodoVar
      .toTarget @todo.labelVar
      .toTarget @todo.isCompletedVar
      .withTransform (serializedTodo, todoPayload) =>
        todoPayload.set(@todo.labelVar,
          Transmitter.Payloads.Variable.setLazy ->
            serializedTodo.get()?.title
        )
        todoPayload.set(@todo.isCompletedVar,
          Transmitter.Payloads.Variable.setLazy ->
            serializedTodo.get()?.completed
        )


class exports.TodoListPersistenceChannel extends Transmitter.Channels.CompositeChannel

  constructor: (@todoList, @todoListPersistenceVar) ->


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
      .withOrigin @todoList
      .withMapOrigin (todo) ->
        serializedVar = new Transmitter.Nodes.Variable()
        serializedVar.todo = todo
        id = serializedId++
        serializedVar.inspect = -> "[serializedTodoVar#{id} #{@todo}]"
        return serializedVar
      .withDerived @serializedTodoList
      .withMapDerived (serializedVar) ->
        todo = new Todo()
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
      .withTransform (serializedTodos) ->
        Transmitter.Payloads.List.setLazy ->
          serializedTodos.get().map ->
            v = new Transmitter.Nodes.Variable()
            id = serializedId++
            v.inspect = -> "[serializedTodoVar#{id} #{@todo}]"
            return v



  @defineChannel ->
    new Transmitter.Channels.SimpleChannel()
      .fromSource @serializedTodoList
      .toConnectionTarget @todoPersistenceChannelVar
      .withTransform (serializedTodoList) =>
        Transmitter.Payloads.Variable.setLazy =>
          if serializedTodoList?
            @createTodoPersistenceChannel(serializedTodoList.get())
          else
            new Transmitter.Channels.PlaceholderChannel()


  createTodoPersistenceChannel: (serializedTodoVars) ->
    if serializedTodoVars.length
      new Transmitter.Channels.CompositeChannel()
        .defineChannel =>
          new Transmitter.Channels.SimpleChannel()
            .inBackwardDirection()
            .fromSource @serializedTodosVar
            .toTargets(serializedTodoVars)
            .withTransform (serializedTodos, serializedTodoVarsPayload) ->
              todos = serializedTodos.get()
              todos = [] unless todos?.length?
              for todoValue, i in todos
                serializedTodoVarsPayload.set(serializedTodoVars[i],
                  new Transmitter.Payloads.Variable.setConst(todoValue))

        .defineChannel =>
          new Transmitter.Channels.SimpleChannel()
            .inForwardDirection()
            .fromSources(serializedTodoVars)
            .toTarget @serializedTodosVar
            .withTransform (serializedTodos) ->
              Transmitter.Payloads.Variable.setLazy ->
                serializedTodos.values().map (v) -> v.get()
    else
      new Transmitter.Channels.ConstChannel()
        .inForwardDirection()
        .toTarget @serializedTodosVar
        .withPayload ->
          Transmitter.Payloads.Variable.setConst([])


