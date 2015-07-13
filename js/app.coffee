'use strict'

$ = require 'jquery'
keycode = require 'keycode'

window.Transmitter = require 'transmitter'


class Todo extends Transmitter.Nodes.Record

  init: (tr, defaults = {}) ->
    {label, isCompleted} = defaults
    @labelVar.updateState(tr, label) if label?
    @isCompletedVar.updateState(tr, isCompleted) if isCompleted?
    return this

  @defineVar 'labelVar'

  @defineVar 'isCompletedVar'


class TodoView extends Transmitter.Nodes.Record

  constructor: (@todo) ->
    @$element = $('<li/>').append(
      $('<div/>', class: 'view').append(
        $('<input/>', class: 'toggle', type: 'checkbox')
        $('<label/>')
        $('<button/>', class: 'destroy')
      )
      $('<input/>', class: 'edit')
    )


  init: (tr) ->
    @editStateVar.updateState(tr, off)
    @startEditChannel.connect(tr)
    @completeEditChannel.connect(tr)
    return this


  @defineLazy 'startEditChannel', ->
   new Transmitter.Channels.SimpleChannel()
     .inBackwardDirection()
     .fromSource @labelDblclickEvt
     .toTarget @editStateVar
     .withTransform (msg) ->
       msg.map(-> yes)


  @defineLazy 'completeEditChannel', ->
   new Transmitter.Channels.SimpleChannel()
     .inBackwardDirection()
     .fromSource @inputKeypressEvt
     .toTarget @editStateVar
     .withTransform (msg) ->
       msg.map( (e) -> keycode(e) not in ['esc', 'enter'])


  createRemoveTodoChannel: ->
    new Transmitter.Channels.SimpleChannel()
      .inBackwardDirection()
      .fromSource @destroyClickEvt
      .withTransform (payload) =>
        if payload.get?
          Transmitter.Payloads.List.removeConst(@todo)
        else
          Transmitter.Payloads.noop()


  @defineLazy 'labelVar', ->
    new Transmitter.DOMElement.TextVar(@$element.find('label')[0])

  @defineLazy 'labelInputVar', ->
    new Transmitter.DOMElement.InputValueVar(@$element.find('.edit')[0])

  @defineLazy 'isCompletedInputVar', ->
    checkbox = @$element.find('.toggle')[0]
    new Transmitter.DOMElement.CheckboxStateVar(checkbox)

  @defineLazy 'labelDblclickEvt', ->
    new Transmitter.DOMElement.DOMEvent(@$element.find('label')[0], 'dblclick')

  @defineLazy 'inputKeypressEvt', ->
    new Transmitter.DOMElement.DOMEvent(@$element.find('.edit')[0], 'keyup')

  @defineLazy 'destroyClickEvt', ->
    new Transmitter.DOMElement.DOMEvent(@$element.find('.destroy')[0], 'click')


  class ClassToggleVar extends Transmitter.Nodes.Variable
    constructor: (@$element, @class) ->
    set: (state) -> @$element.toggleClass(@class, !!state); this
    get: -> @$element.hasClass(@class)


  @defineLazy 'isCompletedClassVar', ->
    new ClassToggleVar(@$element, 'completed')

  @defineLazy 'editStateVar', ->
    new ClassToggleVar(@$element, 'editing')



class TodoListView extends Transmitter.Nodes.Record

  constructor: (@$element) ->

  init: (tr) ->
    @viewElementListChannel.connect(tr)

  @defineLazy 'viewList', ->
    new Transmitter.Nodes.List()

  @defineLazy 'elementList', ->
    new Transmitter.DOMElement.ChildrenList(@$element[0])

  @defineLazy 'viewElementListChannel', ->
    new Transmitter.Channels.SimpleChannel()
      .inForwardDirection()
      .fromSource @viewList
      .toTarget @elementList
      .withTransform (views) ->
        views.updateMatching(
          (view) -> view.$element[0]
          (view, element) -> view.$element[0] == element
        )



class TodoListViewChannel extends Transmitter.Channels.CompositeChannel

  constructor: (@todoList, @todoListView) ->


  @defineChannel ->
    removeTodoChannelList = new Transmitter.ChannelNodes.ChannelList()
    new Transmitter.Channels.SimpleChannel()
      .fromSource @todoListView.viewList
      .toConnectionTarget removeTodoChannelList
      .withTransform (todoViews) =>
        todoViews.map (todoView) =>
          todoView.createRemoveTodoChannel().toTarget(@todoList)


  @defineChannel ->
    new Transmitter.Channels.ListChannel()
    .withOrigin @todoList
    .withMapOrigin (todo) -> new TodoView(todo)
    .initOrigin()
    .withDerived @todoListView.viewList
    .withMatchOriginDerived (todo, todoView) -> todo == todoView.todo
    .withOriginDerivedChannel (todo, todoView) ->
      if todo? and todoView?
        new TodoViewChannel(todo, todoView)
      else
        Transmitter.Channels.getNullChannel()



class TodoViewChannel extends Transmitter.Channels.CompositeChannel

  constructor: (@todo, @view) ->


  @defineChannel ->
    new Transmitter.Channels.VariableChannel()
      .withOrigin @todo.labelVar
      .withDerived @view.labelVar


  @defineChannel ->
    new Transmitter.Channels.VariableChannel()
      .withOrigin @todo.labelVar
      .withDerived @view.labelInputVar


  @defineChannel ->
    new Transmitter.Channels.VariableChannel()
      .withOrigin @todo.isCompletedVar
      .withDerived @view.isCompletedInputVar


  @defineChannel ->
    new Transmitter.Channels.VariableChannel()
      .withOrigin @todo.isCompletedVar
      .withDerived @view.isCompletedClassVar



class NewTodoView extends Transmitter.Nodes.Record

  constructor: (@$element) ->
    @element = @$element[0]


  init: (tr) ->
    @clearNewTodoLabelInputChannel.connect(tr)
    return this


  @defineLazy 'newTodoLabelInputVar', ->
    new Transmitter.DOMElement.InputValueVar(@element)


  @defineLazy 'newTodoKeypressEvt', ->
    new Transmitter.DOMElement.DOMEvent(@element, 'keyup')


  createNewTodoChannel: ->
    new Transmitter.Channels.SimpleChannel()
      .inBackwardDirection()
      .fromSource @newTodoLabelInputVar
      .fromSource @newTodoKeypressEvt
      .withTransform (payloads, tr) =>
        label    = payloads.get(@newTodoLabelInputVar)
        keypress = payloads.get(@newTodoKeypressEvt)

        key = keycode(keypress.get?())
        console.log key, label.get()
        if key is 'enter'
          todo = new Todo().init(tr, label: label.get())
          Transmitter.Payloads.List.appendConst(todo)
        else
          Transmitter.Payloads.noop()


  @defineLazy 'clearNewTodoLabelInputChannel', ->
    new Transmitter.Channels.SimpleChannel()
      .inForwardDirection()
      .fromSource @newTodoKeypressEvt
      .toTarget @newTodoLabelInputVar
      .withTransform (keypress) ->
        key = keycode(keypress.get?())
        console.log key
        if key in ['esc', 'enter']
          Transmitter.Payloads.Variable.setConst('')
        else
          Transmitter.Payloads.noop()



window.todoList = new Transmitter.Nodes.List()
todoList.inspect = -> 'todoList'

window.todoListView = new TodoListView($('.todo-list'))
window.newTodoView = new NewTodoView($('.new-todo'))

todoListViewChannel = new TodoListViewChannel(todoList, todoListView)



Element::inspect = -> '<' + @tagName + ' ... />'
$.Event::inspect = -> '[$Ev ' + @type + ' ... ]'
Event::inspect = -> '[Ev ' + @type + ' ... ]'

# Transmitter.Transmission::loggingFilter = (msg) ->
#   msg.match('todoList')

Transmitter.Transmission::loggingIsEnabled = no

Transmitter.startTransmission (tr) ->
  todoListView.init(tr)
  todoListViewChannel.connect(tr)
  newTodoView.init(tr)
  newTodoView.createNewTodoChannel().toTarget(todoList).connect(tr)

  todo1 = new Todo().init(tr, label: 'Todo 1')
  todo2 = new Todo().init(tr, label: 'Todo 2', isCompleted: yes)

  todoList.updateState(tr, [todo1, todo2])
