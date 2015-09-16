'use strict'

{inspect} = require 'util'

$ = require 'jquery'

window.JQuery = $
window.Transmitter = require 'transmitter'

{VisibilityToggleVar} = require './helpers'
{Todo, NonBlankTodoListChannel, TodoListWithCompleteChannel} = require './model'
{TodoListPersistenceChannel} = require './persistence'
{TodoListView, TodoListViewChannel, NewTodoView, TodoListFooterView,
  TodoListFooterViewChannel, ToggleAllChannel} = require './view'


class App extends Transmitter.Nodes.Record

  @defineLazy 'nonBlankTodoList', ->
    new Transmitter.Nodes.List()

  @defineLazy 'nonBlankTodoListChannel', ->
    new NonBlankTodoListChannel(@nonBlankTodoList, @todoList)


  @defineLazy 'todoList', ->
    new Transmitter.Nodes.List()


  @defineLazy 'todoListPersistenceVar', ->
    new Transmitter.Nodes.PropertyVariable(localStorage, 'todos-transmitter')

  @defineLazy 'todoListPersistenceChannel', ->
    new TodoListPersistenceChannel(@todoList, @todoListPersistenceVar)


  @defineLazy 'todoListWithComplete', ->
    new Transmitter.Nodes.List()

  @defineLazy 'todoListWithCompleteChannel', ->
    new TodoListWithCompleteChannel(@todoList, @todoListWithComplete)


  @defineLazy 'todoListView', ->
    new TodoListView($('.todo-list'))

  @defineLazy 'newTodoView', ->
    new NewTodoView($('.new-todo'))


  @defineLazy 'toggleAllCheckboxVar', ->
    new Transmitter.DOMElement.CheckboxStateVar($('.toggle-all')[0])

  @defineLazy 'toggleAllChangeEvt', ->
    new Transmitter.DOMElement.DOMEvent($('.toggle-all')[0], 'click')

  @defineLazy 'toggleAllIsVisibleVar', ->
    new VisibilityToggleVar($('.toggle-all'))

  @defineLazy 'toggleAllChannel', ->
    new ToggleAllChannel(@todoList, @todoListWithComplete,
      @toggleAllCheckboxVar, @toggleAllChangeEvt)

  @defineLazy 'toggleAllIsVisibleChannel', ->
    new Transmitter.Channels.SimpleChannel()
      .inForwardDirection()
      .fromSource @todoList
      .toTarget @toggleAllIsVisibleVar
      .withTransform (payload) ->
        Transmitter.Payloads.Variable.setLazy ->
          payload.get().length > 0


  @defineLazy 'locationHash', ->
    new Transmitter.Browser.LocationHash()

  @defineLazy 'activeFilter', ->
    new Transmitter.Nodes.Variable()

  @defineLazy 'locationHashChannel', ->
    new Transmitter.Channels.SimpleChannel()
    .inBackwardDirection()
    .fromSource @locationHash
    .toTarget @activeFilter
    .withTransform (locationHashPayload) ->
      locationHashPayload.map (value) ->
        switch value
          when '#/active' then 'active'
          when '#/completed' then 'completed'
          else 'all'


  @defineLazy 'todoListFooterView',
    -> new TodoListFooterView($('.footer'))

  @defineLazy 'todoListViewChannel', ->
    new TodoListViewChannel(
      @todoList, @todoListWithComplete, @todoListView, @activeFilter)

  @defineLazy 'todoListFooterViewChannel', ->
    new TodoListFooterViewChannel(
      @todoList, @todoListWithComplete, @todoListFooterView, @activeFilter)

  init: (tr) ->
    @nonBlankTodoListChannel.init(tr)
    @todoListPersistenceChannel.init(tr)

    @todoListView.init(tr)
    @todoListWithCompleteChannel.init(tr)

    @todoListViewChannel.init(tr)
    @todoListFooterViewChannel.init(tr)
    @toggleAllChannel.init(tr)
    @toggleAllIsVisibleChannel.init(tr)
    @newTodoView.init(tr)
    @newTodoView.createNewTodoChannel().toTarget(@todoList).init(tr)

    @locationHashChannel.init(tr)
    @locationHash.originate(tr)

    unless @todoListPersistenceVar.get()
      @todoListPersistenceVar.set(
        JSON.stringify([{title: 'Todo 1', completed: no},
        {title: 'Todo 2', completed: yes}])
      )

    @todoListPersistenceVar.originate(tr)

    # todo1 = new Todo().init(tr, label: 'Todo 1', isCompleted: no)
    # todo2 = new Todo().init(tr, label: 'Todo 2', isCompleted: yes)

    # todoList.init(tr, [todo1, todo2])


Element::inspect = -> '<' + @tagName + ' ... />'
$.Event::inspect = -> '[$Ev ' + @type + ' ... ]'
Event::inspect = -> '[Ev ' + @type + ' ... ]'

Transmitter.Transmission::loggingFilter = (msg) ->
  msg.match(/activeFilter/)
  # msg.match(/label(Input)?Var|MM/)

Transmitter.Transmission::loggingIsEnabled = no

app = new App()

Transmitter.startTransmission (tr) -> app.init(tr)
