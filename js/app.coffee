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


window.nonBlankTodoList = new Transmitter.Nodes.List()
nonBlankTodoList.inspect = -> 'nonBlankTodoList'
todoList = new Transmitter.Nodes.List()
todoList.inspect = -> 'todoList'

todoListPersistenceVar =
  new Transmitter.Nodes.PropertyVariable(localStorage, 'todos-transmitter')
todoListPersistenceVar.inspect = -> 'todoListPersistenceVar'
todoListPersistenceChannel =
  new TodoListPersistenceChannel(todoList, todoListPersistenceVar)


todoListWithComplete = new Transmitter.Nodes.List()
todoListWithComplete.inspect = -> 'todoListWithComplete'
todoListWithCompleteChannel =
  new TodoListWithCompleteChannel(todoList, todoListWithComplete)

window.todoListView = new TodoListView($('.todo-list'))
window.newTodoView = new NewTodoView($('.new-todo'))
window.toggleAllCheckboxVar =
  new Transmitter.DOMElement.CheckboxStateVar($('.toggle-all')[0])

window.toggleAllChangeEvt =
  new Transmitter.DOMElement.DOMEvent($('.toggle-all')[0], 'click')

window.toggleAllIsVisibleVar =
  new VisibilityToggleVar($('.toggle-all'))

toggleAllChannel =
  new ToggleAllChannel(todoList, todoListWithComplete, toggleAllCheckboxVar, toggleAllChangeEvt)

toggleAllIsVisibleChannel =
  new Transmitter.Channels.SimpleChannel()
    .inForwardDirection()
    .fromSource todoList
    .toTarget toggleAllIsVisibleVar
    .withTransform (payload) ->
      Transmitter.Payloads.Variable.setLazy ->
        payload.get().length > 0

locationHash = new Transmitter.Browser.LocationHash()
activeFilter = new Transmitter.Nodes.Variable()
activeFilter.inspect = -> 'activeFilter'

locationHashChannel = new Transmitter.Channels.SimpleChannel()
  .inBackwardDirection()
  .fromSource locationHash
  .toTarget activeFilter
  .withTransform (locationHashPayload) ->
    locationHashPayload.map (value) ->
      switch value
        when '#/active' then 'active'
        when '#/completed' then 'completed'
        else 'all'


todoListFooterView = new TodoListFooterView($('.footer'))

nonBlankTodoListChannel = new NonBlankTodoListChannel(nonBlankTodoList, todoList)
todoListViewChannel = new TodoListViewChannel(
  todoList, todoListWithComplete, todoListView, activeFilter)
todoListFooterViewChannel = new TodoListFooterViewChannel(
  todoList, todoListWithComplete, todoListFooterView, activeFilter)



Element::inspect = -> '<' + @tagName + ' ... />'
$.Event::inspect = -> '[$Ev ' + @type + ' ... ]'
Event::inspect = -> '[Ev ' + @type + ' ... ]'

Transmitter.Transmission::loggingFilter = (msg) ->
  msg.match(/activeFilter/)
  # msg.match(/label(Input)?Var|MM/)

Transmitter.Transmission::loggingIsEnabled = no

Transmitter.startTransmission (tr) ->
  todoListView.init(tr)
  nonBlankTodoListChannel.init(tr)
  todoListWithCompleteChannel.init(tr)
  todoListPersistenceChannel.init(tr)
  todoListViewChannel.init(tr)
  todoListFooterViewChannel.init(tr)
  toggleAllChannel.init(tr)
  toggleAllIsVisibleChannel.init(tr)
  newTodoView.init(tr)
  newTodoView.createNewTodoChannel().toTarget(todoList).init(tr)

  locationHashChannel.init(tr)
  locationHash.originate(tr)

  unless todoListPersistenceVar.get()
    todoListPersistenceVar.set(
      JSON.stringify([{title: 'Todo 1', completed: no},
      {title: 'Todo 2', completed: yes}])
    )

  todoListPersistenceVar.originate(tr)

  # todo1 = new Todo().init(tr, label: 'Todo 1', isCompleted: no)
  # todo2 = new Todo().init(tr, label: 'Todo 2', isCompleted: yes)

  # todoList.init(tr, [todo1, todo2])
